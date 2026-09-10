import SwiftUI
import UIKit
import Photos
import PhotosUI
import CoreLocation

struct AddPhotosView: View {
    let nightId: String
    let start: Date
    let end: Date
    let routeCoordinates: [CLLocationCoordinate2D]
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .loading
    @State private var assets: [PHAsset] = []
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var selected: Set<String> = []
    @State private var manualItems: [PhotosPickerItem] = []
    @State private var uploaded = 0
    @State private var failed = 0
    @State private var uploadTotal = 0

    private let apiService = APIService()

    private let neonPink = Color(
        red: 1.0,
        green: 0.10,
        blue: 0.58
    )

    enum Phase {
        case loading
        case denied
        case empty
        case review
        case uploading
        case done
    }

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch phase {
            case .loading:
                message("Looking through your photos…", spinner: true)
            case .denied:
                deniedView
            case .empty:
                emptyView
            case .uploading:
                message(
                    "Adding \(uploaded + failed) of \(uploadTotal)…",
                    spinner: true
                )
            case .done:
                message(
                    failed == 0
                        ? "Added \(uploaded) photo\(uploaded == 1 ? "" : "s")."
                        : "Added \(uploaded), \(failed) failed."
                )
            case .review:
                reviewGrid
            }
        }
        .task { await load() }
        .onChange(of: manualItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await uploadManual(items) }
        }
    }

    private var reviewGrid: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Text("\(selected.count) selected")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button("Add") { Task { await uploadAssets() } }
                    .foregroundStyle(neonPink)
                    .fontWeight(.semibold)
                    .disabled(selected.isEmpty)
                    .opacity(selected.isEmpty ? 0.4 : 1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        thumbCell(asset)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)

                manualPickerButton
                    .padding(.horizontal, 6)
                    .padding(.vertical, 20)
            }
        }
    }

    private var manualPickerButton: some View {
        PhotosPicker(
            selection: $manualItems,
            maxSelectionCount: 20,
            matching: .images
        ) {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                Text("Pick other photos")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(neonPink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(neonPink.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Text("No photos found from around this Night.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            manualPickerButton
                .padding(.horizontal, 40)

            Button("Close") { dismiss() }
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Text(
                "AFTR can't see your library, but you can still pick photos to add."
            )
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            manualPickerButton
                .padding(.horizontal, 40)

            Button("Close") { dismiss() }
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func thumbCell(_ asset: PHAsset) -> some View {
        let id = asset.localIdentifier
        let isSelected = selected.contains(id)

        return ZStack(alignment: .topTrailing) {
            Group {
                if let image = thumbnails[id] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.white.opacity(0.06)
                }
            }
            .frame(height: 118)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? neonPink : Color.clear,
                        lineWidth: 2.5
                    )
            }

            Image(
                systemName: isSelected
                    ? "checkmark.circle.fill"
                    : "circle"
            )
            .font(.system(size: 20))
            .foregroundStyle(
                isSelected ? neonPink : Color.white.opacity(0.85)
            )
            .padding(6)
            .shadow(radius: 3)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected { selected.remove(id) }
            else { selected.insert(id) }
        }
    }

    private func message(
        _ text: String,
        spinner: Bool = false
    ) -> some View {
        VStack(spacing: 14) {
            if spinner {
                ProgressView().tint(neonPink)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if phase == .done {
                Button("Done") {
                    onDone()
                    dismiss()
                }
                .foregroundStyle(neonPink)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Loading

    @MainActor
    private func load() async {
        guard phase == .loading else { return }

        guard await PhotoSelector.requestAccess() else {
            phase = .denied
            return
        }

        let found = PhotoSelector.candidates(
            start: start,
            end: end,
            near: routeCoordinates
        )

        guard !found.isEmpty else {
            phase = .empty
            return
        }

        assets = found
        selected = Set(found.map(\.localIdentifier))
        phase = .review

        let size = CGSize(width: 240, height: 240)
        for asset in found {
            if let image = await PhotoSelector.thumbnail(
                for: asset,
                size: size
            ) {
                thumbnails[asset.localIdentifier] = image
            }
        }
    }

    // MARK: - Uploading

    struct PendingUpload {
        let data: Data
        let filename: String
        let takenAt: String?
        let latitude: Double?
        let longitude: Double?
    }

    @MainActor
    private func uploadAssets() async {
        let formatter = ISO8601DateFormatter()
        let chosen = assets.filter {
            selected.contains($0.localIdentifier)
        }

        phase = .uploading
        uploaded = 0
        failed = 0
        uploadTotal = chosen.count

        var pending: [PendingUpload] = []
        for asset in chosen {
            guard let bytes = await PhotoSelector.uploadBytes(for: asset)
            else {
                failed += 1
                continue
            }
            pending.append(
                PendingUpload(
                    data: bytes.data,
                    filename: bytes.filename,
                    takenAt: asset.creationDate
                        .map(formatter.string(from:)),
                    latitude: asset.location?.coordinate.latitude,
                    longitude: asset.location?.coordinate.longitude
                )
            )
        }

        await sendInParallel(pending)
        phase = .done
    }

    @MainActor
    private func uploadManual(_ items: [PhotosPickerItem]) async {
        phase = .uploading
        uploaded = 0
        failed = 0
        uploadTotal = items.count

        var pending: [PendingUpload] = []
        for (index, item) in items.enumerated() {
            guard
                let raw = try? await item.loadTransferable(
                    type: Data.self
                ),
                let jpeg = PhotoSelector.downscaledJPEG(from: raw)
            else {
                failed += 1
                continue
            }
            pending.append(
                PendingUpload(
                    data: jpeg,
                    filename: "pick-\(index).jpg",
                    takenAt: nil,
                    latitude: nil,
                    longitude: nil
                )
            )
        }

        await sendInParallel(pending)
        manualItems = []
        phase = .done
    }

    /// Upload up to 3 at a time.
    @MainActor
    private func sendInParallel(_ pending: [PendingUpload]) async {
        guard !pending.isEmpty else { return }

        let service = apiService
        let night = nightId

        await withTaskGroup(of: Bool.self) { group in
            var next = 0

            func submit() {
                guard next < pending.count else { return }
                let item = pending[next]
                next += 1
                group.addTask {
                    do {
                        _ = try await service.uploadMedia(
                            nightId: night,
                            data: item.data,
                            contentType: "image/jpeg",
                            filename: item.filename,
                            takenAt: item.takenAt,
                            latitude: item.latitude,
                            longitude: item.longitude
                        )
                        return true
                    } catch {
                        return false
                    }
                }
            }

            for _ in 0..<min(3, pending.count) {
                submit()
            }

            for await ok in group {
                if ok { uploaded += 1 } else { failed += 1 }
                submit()
            }
        }
    }
}

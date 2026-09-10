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
                message("Adding photos…", spinner: true)
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

    @MainActor
    private func uploadAssets() async {
        phase = .uploading
        uploaded = 0
        failed = 0

        let formatter = ISO8601DateFormatter()
        let chosen = assets.filter {
            selected.contains($0.localIdentifier)
        }

        for asset in chosen {
            guard let bytes = await PhotoSelector.uploadBytes(for: asset)
            else {
                failed += 1
                continue
            }

            await send(
                data: bytes.data,
                contentType: bytes.contentType,
                filename: bytes.filename,
                takenAt: asset.creationDate.map(formatter.string(from:)),
                latitude: asset.location?.coordinate.latitude,
                longitude: asset.location?.coordinate.longitude
            )
        }

        phase = .done
    }

    @MainActor
    private func uploadManual(_ items: [PhotosPickerItem]) async {
        phase = .uploading
        uploaded = 0
        failed = 0

        for (index, item) in items.enumerated() {
            guard
                let data = try? await item.loadTransferable(
                    type: Data.self
                )
            else {
                failed += 1
                continue
            }

            let contentType = Self.sniffContentType(data)
            let ext = contentType.split(separator: "/").last ?? "jpg"

            await send(
                data: data,
                contentType: contentType,
                filename: "pick-\(index).\(ext)",
                takenAt: nil,
                latitude: nil,
                longitude: nil
            )
        }

        manualItems = []
        phase = .done
    }

    @MainActor
    private func send(
        data: Data,
        contentType: String,
        filename: String,
        takenAt: String?,
        latitude: Double?,
        longitude: Double?
    ) async {
        do {
            _ = try await apiService.uploadMedia(
                nightId: nightId,
                data: data,
                contentType: contentType,
                filename: filename,
                takenAt: takenAt,
                latitude: latitude,
                longitude: longitude
            )
            uploaded += 1
        } catch {
            failed += 1
        }
    }

    private static func sniffContentType(_ data: Data) -> String {
        let bytes = [UInt8](data.prefix(12))

        if bytes.count >= 4,
           bytes[0] == 0x89, bytes[1] == 0x50,
           bytes[2] == 0x4E, bytes[3] == 0x47 {
            return "image/png"
        }

        if bytes.count >= 12,
           bytes[4] == 0x66, bytes[5] == 0x74,
           bytes[6] == 0x79, bytes[7] == 0x70 {
            // ...ftyp... -> HEIC/HEIF container
            return "image/heic"
        }

        return "image/jpeg"
    }
}

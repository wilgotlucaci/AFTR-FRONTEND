import SwiftUI
import UIKit
import Photos
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
                message(
                    "AFTR needs photo access to add pictures from your Night. Enable it in Settings."
                )
            case .empty:
                message("No photos found from during this Night.")
            case .uploading:
                message(
                    "Adding \(uploaded)/\(selected.count)…",
                    spinner: true
                )
            case .done:
                message("Added \(uploaded) photo\(uploaded == 1 ? "" : "s").")
            case .review:
                reviewGrid
            }
        }
        .task { await load() }
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

                Button("Add") { Task { await upload() } }
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
                .padding(.bottom, 24)
            }
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

            if phase == .denied || phase == .empty || phase == .done {
                Button("Close") {
                    if phase == .done { onDone() }
                    dismiss()
                }
                .foregroundStyle(neonPink)
                .padding(.top, 4)
            }
        }
    }

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

    @MainActor
    private func upload() async {
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

            do {
                _ = try await apiService.uploadMedia(
                    nightId: nightId,
                    data: bytes.data,
                    contentType: bytes.contentType,
                    filename: bytes.filename,
                    takenAt: asset.creationDate.map(formatter.string(from:)),
                    latitude: asset.location?.coordinate.latitude,
                    longitude: asset.location?.coordinate.longitude
                )
                uploaded += 1
            } catch {
                failed += 1
            }
        }

        phase = .done
    }
}

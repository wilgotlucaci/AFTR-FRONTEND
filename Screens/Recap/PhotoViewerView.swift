import SwiftUI

struct PhotoViewerView: View {
    let media: [NightMedia]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(
                    Array(media.enumerated()),
                    id: \.offset
                ) { position, item in
                    ZoomablePhoto(url: item.imageURL)
                        .overlay(alignment: .bottom) {
                            caption(for: item)
                        }
                        .tag(position)
                }
            }
            .tabViewStyle(
                .page(
                    indexDisplayMode: media.count > 1
                        ? .automatic
                        : .never
                )
            )
            .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.trailing, 18)
            .padding(.top, 8)
        }
        .onAppear {
            index = min(
                max(startIndex, 0),
                max(media.count - 1, 0)
            )
        }
    }

    @ViewBuilder
    private func caption(for item: NightMedia) -> some View {
        if let venue = item.venue_name {
            captionText(venue)
        } else if let taken = item.taken_at,
                  let date = parseISODate(taken) {
            captionText(
                date.formatted(date: .abbreviated, time: .shortened)
            )
        }
    }

    private func captionText(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 54)
    }

    private func parseISODate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()

        if let date = formatter.date(from: string) {
            return date
        }

        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        return formatter.date(from: string)
    }
}

private struct ZoomablePhoto: View {
    let url: URL?

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(max(lastScale * value, 1), 4)
                            }
                            .onEnded { _ in
                                lastScale = scale
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(duration: 0.25)) {
                            scale = scale > 1 ? 1 : 2.5
                            lastScale = scale
                        }
                    }

            case .failure:
                Image(systemName: "photo")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.25))

            default:
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

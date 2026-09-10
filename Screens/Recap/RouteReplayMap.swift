import SwiftUI
import MapKit

/// The night's route on a dark map, with a play button that walks a
/// glowing dot along the path while venue pins light up as it "arrives".
struct RouteReplayMap: View {
    let routes: [RouteParticipant]
    let venues: [VenueTimelineItem]

    var accent = Color(red: 1.0, green: 0.10, blue: 0.58)

    @State private var progress: Double = 0
    @State private var isPlaying = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let duration: Double = 9
    private let fps: Double = 30
    private let ticker = Timer
        .publish(every: 1.0 / 30.0, on: .main, in: .common)
        .autoconnect()

    private var primaryRoute: RouteParticipant? {
        routes.max { $0.points.count < $1.points.count }
    }

    private var primaryCoords: [CLLocationCoordinate2D] {
        primaryRoute?.coordinates ?? []
    }

    private var allCoords: [CLLocationCoordinate2D] {
        routes.flatMap(\.coordinates)
    }

    private var playhead: CLLocationCoordinate2D? {
        let pts = primaryCoords
        guard pts.count >= 2 else { return pts.first }

        let pos = progress * Double(pts.count - 1)
        let i = min(Int(pos), pts.count - 2)
        let f = pos - Double(i)

        return CLLocationCoordinate2D(
            latitude: pts[i].latitude
                + (pts[i + 1].latitude - pts[i].latitude) * f,
            longitude: pts[i].longitude
                + (pts[i + 1].longitude - pts[i].longitude) * f
        )
    }

    /// 0...1 progress point at which the dot is nearest this coordinate.
    private func arrivalFraction(_ coord: CLLocationCoordinate2D) -> Double {
        let pts = primaryCoords
        guard pts.count >= 2 else { return 0 }

        var bestIndex = 0
        var bestDistance = Double.greatestFiniteMagnitude

        for (index, point) in pts.enumerated() {
            let dLat = point.latitude - coord.latitude
            let dLon = point.longitude - coord.longitude
            let d = dLat * dLat + dLon * dLon
            if d < bestDistance {
                bestDistance = d
                bestIndex = index
            }
        }

        return Double(bestIndex) / Double(pts.count - 1)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(
                initialPosition: .region(
                    Self.region(for: allCoords)
                )
            ) {
                ForEach(routes) { route in
                    MapPolyline(coordinates: route.coordinates)
                        .stroke(
                            route.id == primaryRoute?.id
                                ? accent
                                : accent.opacity(0.28),
                            style: StrokeStyle(
                                lineWidth: 3,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }

                ForEach(venues) { venue in
                    if let coordinate = venue.coordinate {
                        let reached = hasStarted
                            && progress >= arrivalFraction(coordinate) - 0.002

                        Annotation(
                            venue.venue_name,
                            coordinate: coordinate
                        ) {
                            venuePin(reached: reached)
                        }
                        .annotationTitles(.hidden)
                    }
                }

                if hasStarted, let head = playhead {
                    Annotation("", coordinate: head) {
                        playheadDot
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControlVisibility(.hidden)
            .allowsHitTesting(false)
            .environment(\.colorScheme, .dark)

            progressBar

            Button {
                toggle()
            } label: {
                Image(systemName: buttonIcon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle().stroke(accent.opacity(0.5), lineWidth: 1)
                    }
            }
            .padding(12)
        }
        .onReceive(ticker) { _ in
            guard isPlaying else { return }
            progress += 1.0 / fps / duration
            if progress >= 1 {
                progress = 1
                isPlaying = false
            }
        }
    }

    private var hasStarted: Bool {
        isPlaying || progress > 0
    }

    private func venuePin(reached: Bool) -> some View {
        let size: CGFloat = reached ? 16 : 11
        return ZStack {
            Circle()
                .fill(reached ? accent : accent.opacity(0.35))
            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
        }
        .frame(width: size, height: size)
        .shadow(
            color: accent.opacity(reached ? 0.9 : 0.25),
            radius: reached ? 8 : 3
        )
        .animation(.spring(duration: 0.3), value: reached)
    }

    private var playheadDot: some View {
        ZStack {
            Circle().fill(accent.opacity(0.22)).frame(width: 28, height: 28)
            Circle().fill(accent).frame(width: 13, height: 13)
            Circle().stroke(Color.white, lineWidth: 2).frame(width: 13, height: 13)
        }
        .shadow(color: accent, radius: 8)
    }

    private var progressBar: some View {
        VStack(spacing: 0) {
            Spacer()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.14))
                    Rectangle()
                        .fill(accent)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 3)
        }
    }

    private var buttonIcon: String {
        if isPlaying { return "pause.fill" }
        return progress >= 1 ? "arrow.counterclockwise" : "play.fill"
    }

    private func toggle() {
        if reduceMotion {
            withAnimation { progress = progress >= 1 ? 0 : 1 }
            return
        }
        if progress >= 1 { progress = 0 }
        isPlaying.toggle()
    }

    static func region(
        for coordinates: [CLLocationCoordinate2D]
    ) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(
                    latitudeDelta: 0.05,
                    longitudeDelta: 0.05
                )
            )
        }

        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
                longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
            )
        )
    }
}

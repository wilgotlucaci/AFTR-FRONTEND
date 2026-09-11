import SwiftUI
import CoreLocation
import Combine

struct SafeWalkView: View {
    let home: HomeLocation
    var onFinish: () -> Void

    @State private var token: String?
    @State private var shareURL: URL?
    @State private var arrived = false
    @State private var lastPing: Date = .distantPast
    @State private var errorText = ""

    @StateObject private var tracker = SafeWalkTracker()

    private let apiService = APIService()
    private let neonPink = Color(red: 1.0, green: 0.10, blue: 0.58)
    private let softPink = Color(red: 1.0, green: 0.32, blue: 0.72)

    var body: some View {
        ZStack {
            background

            VStack(spacing: 22) {
                Spacer()

                Image(systemName: arrived ? "house.fill" : "figure.walk.motion")
                    .font(.system(size: 40))
                    .foregroundStyle(arrived ? .green : neonPink)
                    .shadow(color: (arrived ? .green : neonPink).opacity(0.6), radius: 14)

                VStack(spacing: 8) {
                    Text(arrived ? "Home safe" : "Get home safe")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(
                        arrived
                            ? "Your friend was told you made it."
                            : "Share the link. AFTR tells whoever has it when you're home, then stops."
                    )
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                }

                if !errorText.isEmpty {
                    Text(errorText)
                        .font(.caption).foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                if arrived {
                    filledButton("Done") { finish() }
                } else {
                    if let shareURL {
                        ShareLink(item: shareURL) {
                            filledLabel("Share live link", icon: "square.and.arrow.up")
                        }
                    } else {
                        filledLabel("Preparing link…", icon: "hourglass")
                            .opacity(0.6)
                    }

                    Button {
                        Task { await markArrived() }
                    } label: {
                        Text("I'm home — stop sharing")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(softPink)
                    }

                    Button {
                        finish()
                    } label: {
                        Text("Skip")
                            .font(.footnote)
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 30)
        }
        .task { await start() }
        .onChange(of: tracker.lastLocation?.timestamp) { _, _ in
            guard let location = tracker.lastLocation else { return }
            handle(location)
        }
    }

    // MARK: - Flow

    private func start() async {
        do {
            let result = try await apiService.startSafeWalk()
            await MainActor.run {
                token = result.token
                shareURL = URL(string: result.url)
            }
            tracker.start()
        } catch {
            await MainActor.run {
                errorText = "Couldn't start the link. You can still head home."
            }
        }
    }

    private func handle(_ location: CLLocation) {
        guard let token, !arrived else { return }

        if location.distance(from: home.location) <= home.radius_meters {
            Task { await markArrived() }
            return
        }

        if Date().timeIntervalSince(lastPing) > 20 {
            lastPing = Date()
            Task {
                try? await apiService.pingSafeWalk(
                    token: token,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
        }
    }

    private func markArrived() async {
        if let token {
            try? await apiService.arriveSafeWalk(token: token)
        }
        await MainActor.run {
            arrived = true
            tracker.stop()
        }
    }

    private func finish() {
        tracker.stop()
        onFinish()
    }

    // MARK: - UI bits

    private func filledButton(
        _ title: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { filledLabel(title, icon: nil) }
    }

    private func filledLabel(_ title: String, icon: String?) -> some View {
        HStack(spacing: 8) {
            if let icon { Image(systemName: icon) }
            Text(title).font(.system(size: 17, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(
            LinearGradient(
                colors: [Color.white, softPink],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .foregroundStyle(.black)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [neonPink.opacity(0.16), .clear],
                center: .top, startRadius: 20, endRadius: 400
            )
            .ignoresSafeArea()
        }
    }
}

final class SafeWalkTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var lastLocation: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 40
        manager.allowsBackgroundLocationUpdates = false
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = location
        }
    }
}

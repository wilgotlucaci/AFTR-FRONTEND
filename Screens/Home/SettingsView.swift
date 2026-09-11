import SwiftUI
import CoreLocation

struct SettingsView: View {
    @Binding var isLoggedIn: Bool
    @Environment(\.dismiss) private var dismiss

    @AppStorage("autoEndAtHome") private var autoEndAtHome = true
    @AppStorage("getHomeSafeEnabled") private var getHomeSafeEnabled = false

    @State private var home: HomeLocation?
    @State private var isBusy = false
    @State private var status = ""

    private let apiService = APIService()
    private let authService = AuthService()
    private let locator = CurrentLocationOnce()

    private let neonPink = Color(red: 1.0, green: 0.10, blue: 0.58)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    section("HOME") {
                        Text("AFTR uses this to end a Night automatically when you get home. It never leaves your account.")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.45))

                        if home != nil {
                            Label("Home is set", systemImage: "house.fill")
                                .font(.subheadline)
                                .foregroundStyle(.white)

                            HStack(spacing: 10) {
                                pillButton("Update", filled: false) { setHome() }
                                pillButton("Clear", filled: false, destructive: true) {
                                    clearHome()
                                }
                            }
                        } else {
                            pillButton("Set home to my current location", filled: true) {
                                setHome()
                            }
                        }

                        if !status.isEmpty {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }

                    section("DURING A NIGHT") {
                        Toggle(isOn: $autoEndAtHome) {
                            Text("End the Night when I get home")
                                .foregroundStyle(.white)
                        }
                        .tint(neonPink)
                        .disabled(home == nil)
                        .opacity(home == nil ? 0.45 : 1)

                        Toggle(isOn: $getHomeSafeEnabled) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Offer \u{201C}get home safe\u{201D} after a Night")
                                    .foregroundStyle(.white)
                                Text("Share a live link with a friend until you're home.")
                                    .font(.caption2)
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                        }
                        .tint(neonPink)
                    }

                    Button {
                        Task {
                            await authService.signOut()
                            await MainActor.run {
                                isLoggedIn = false
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Sign out")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 6)
                }
                .padding(22)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            home = try? await apiService.getHome()
        }
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.bottom, 4)
    }

    private func section<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption2).fontWeight(.semibold).tracking(1.3)
                .foregroundStyle(Color.white.opacity(0.42))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func pillButton(
        _ title: LocalizedStringKey,
        filled: Bool,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isBusy { ProgressView().tint(filled ? .black : .white) }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(
                destructive ? .red : (filled ? .black : .white)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                filled
                    ? AnyShapeStyle(Color.white)
                    : AnyShapeStyle(Color.white.opacity(0.08))
            )
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .disabled(isBusy)
    }

    private func setHome() {
        isBusy = true
        status = ""
        Task {
            do {
                let coord = try await locator.get()
                let saved = try await apiService.setHome(
                    latitude: coord.latitude,
                    longitude: coord.longitude
                )
                await MainActor.run {
                    home = saved
                    isBusy = false
                    status = String(localized: "Saved.")
                }
            } catch {
                await MainActor.run {
                    isBusy = false
                    status = String(
                        localized: "Couldn't get your location. Allow location access and try again."
                    )
                }
            }
        }
    }

    private func clearHome() {
        isBusy = true
        Task {
            try? await apiService.clearHome()
            await MainActor.run {
                home = nil
                isBusy = false
                status = ""
            }
        }
    }
}

enum LocationFetchError: Error {
    case denied
}

/// One-shot current-location fetch for setting "home".
final class CurrentLocationOnce: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    func get() async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                finish(.failure(LocationFetchError.denied))
            default:
                manager.requestLocation()
            }
        }
    }

    private func finish(_ result: Result<CLLocationCoordinate2D, Error>) {
        guard let cont = continuation else { return }
        continuation = nil
        switch result {
        case .success(let c): cont.resume(returning: c)
        case .failure(let e): cont.resume(throwing: e)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(.failure(LocationFetchError.denied))
        default:
            break
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        if let coord = locations.last?.coordinate {
            finish(.success(coord))
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        finish(.failure(error))
    }
}

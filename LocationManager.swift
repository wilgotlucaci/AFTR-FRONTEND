import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var isTracking = false
    @Published var lastLocation: CLLocation?
    @Published var lastError: String?

    private let manager = CLLocationManager()
    private let apiService = APIService()

    private var activeNightId: String?

    private var lastReceivedLocation: CLLocation?
    private var lastUploadedLocation: CLLocation?
    private var lastUploadDate: Date?

    private let maxReasonableSpeed: CLLocationSpeed = 45
    // 45 m/s ≈ 162 km/h

    override init() {
        authorizationStatus = manager.authorizationStatus

        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 25
        manager.activityType = .other
        manager.pausesLocationUpdatesAutomatically = true
    }

    func startTracking(nightId: String) {
        activeNightId = nightId
        lastError = nil

        lastReceivedLocation = nil
        lastUploadedLocation = nil
        lastUploadDate = nil

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse:
            startLocationUpdates()
            manager.requestAlwaysAuthorization()

        case .authorizedAlways:
            startLocationUpdates()

        case .denied, .restricted:
            isTracking = false
            lastError = "Location permission is required."

        @unknown default:
            isTracking = false
            lastError = "Unknown location permission status."
        }
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false

        activeNightId = nil

        lastReceivedLocation = nil
        lastUploadedLocation = nil
        lastUploadDate = nil

        isTracking = false
        lastError = nil
    }

    private func startLocationUpdates() {
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true

        manager.startUpdatingLocation()

        isTracking = true
        lastError = nil
    }

    private func isReasonableLocation(
        _ location: CLLocation
    ) -> Bool {
        guard location.horizontalAccuracy >= 0 else {
            return false
        }

        guard location.horizontalAccuracy <= 100 else {
            return false
        }

        guard let previousLocation = lastReceivedLocation else {
            return true
        }

        let distance = location.distance(
            from: previousLocation
        )

        let timeDifference = location.timestamp.timeIntervalSince(
            previousLocation.timestamp
        )

        guard timeDifference > 0 else {
            return false
        }

        let calculatedSpeed = distance / timeDifference

        if calculatedSpeed > maxReasonableSpeed {
            return false
        }

        return true
    }

    private func shouldUpload(
        location: CLLocation
    ) -> Bool {
        guard let lastUploadDate else {
            return true
        }

        let secondsSinceLastUpload = Date().timeIntervalSince(
            lastUploadDate
        )

        let speed = max(location.speed, 0)

        let minimumTimeInterval: TimeInterval

        if speed < 0.5 {
            minimumTimeInterval = 300
        } else if speed < 3 {
            minimumTimeInterval = 60
        } else {
            minimumTimeInterval = 30
        }

        if secondsSinceLastUpload >= minimumTimeInterval {
            return true
        }

        guard let lastUploadedLocation else {
            return true
        }

        let distance = location.distance(
            from: lastUploadedLocation
        )

        if speed >= 3 && distance >= 100 {
            return true
        }

        if speed >= 0.5 && distance >= 75 {
            return true
        }

        return false
    }

    private func handleLocation(
        _ location: CLLocation
    ) {
        let isReasonable = isReasonableLocation(location)

        lastReceivedLocation = location

        guard isReasonable else {
            return
        }

        guard shouldUpload(location: location) else {
            return
        }

        lastUploadedLocation = location
        lastUploadDate = Date()

        let speed: Double?

        if location.speed >= 0 {
            speed = location.speed
        } else {
            speed = nil
        }

        let horizontalAccuracy: Double?

        if location.horizontalAccuracy >= 0 {
            horizontalAccuracy = location.horizontalAccuracy
        } else {
            horizontalAccuracy = nil
        }

        guard let activeNightId else {
            return
        }

        Task {
            do {
                try await apiService.sendLocation(
                    nightId: activeNightId,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    speed: speed,
                    horizontalAccuracy: horizontalAccuracy
                )
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus

            guard activeNightId != nil else {
                return
            }

            switch manager.authorizationStatus {
            case .authorizedWhenInUse:
                startLocationUpdates()
                manager.requestAlwaysAuthorization()

            case .authorizedAlways:
                startLocationUpdates()

            case .denied, .restricted:
                isTracking = false
                lastError = "Location permission is required."

            case .notDetermined:
                break

            @unknown default:
                isTracking = false
                lastError = "Unknown location permission status."
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            return
        }

        Task { @MainActor in
            lastError = nil
            lastLocation = location

            handleLocation(location)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        let locationError = error as? CLError

        if locationError?.code == .locationUnknown {
            return
        }

        Task { @MainActor in
            lastError = error.localizedDescription
        }
    }
}

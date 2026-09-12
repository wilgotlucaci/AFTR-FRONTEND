import Foundation
import CoreLocation
import Combine
import ActivityKit

/// App-wide owner of "is a Night currently active" state.
///
/// This used to live inside ActiveNightView itself, which meant the whole
/// app was locked to that one screen for the length of a Night - there was
/// no way to browse past recaps while AFTR was tracking you. Hoisting it
/// here lets the user navigate freely; ActiveNightView becomes a detail
/// screen you can open and dismiss, while tracking (and auto-end-at-home)
/// keeps running underneath regardless of what's on screen.
@MainActor
final class NightSession: ObservableObject {
    @Published private(set) var nightId: String?
    @Published private(set) var nightTitle: String = ""
    @Published private(set) var startedAt: Date = Date()
    @Published private(set) var isEndingNight = false
    @Published var lastStatus = ""

    /// Set right after a Night ends (manually or automatically) when
    /// "get home safe" should be offered. The app root observes this and
    /// presents SafeWalkView regardless of which screen is on top.
    @Published var pendingSafeWalkHome: HomeLocation?

    let locationManager = LocationManager()
    private let apiService = APIService()

    private var home: HomeLocation?
    private var nearHomeSince: Date?
    private var cancellables = Set<AnyCancellable>()

    var isActive: Bool { nightId != nil }

    init() {
        locationManager.$lastLocation
            .sink { [weak self] location in
                self?.checkAutoEnd(location)
            }
            .store(in: &cancellables)
    }

    /// Starts tracking for a brand-new Night.
    func start(nightId: String, title: String) {
        attach(nightId: nightId, title: title, startedAt: Date())
    }

    /// Reattaches to a Night that's already active server-side - e.g. the
    /// app was relaunched mid-Night. Preserves the original start time.
    func resume(nightId: String, title: String, startedAt: Date) {
        guard self.nightId != nightId else { return }
        attach(nightId: nightId, title: title, startedAt: startedAt)
    }

    private func attach(nightId: String, title: String, startedAt: Date) {
        self.nightId = nightId
        self.nightTitle = title
        self.startedAt = startedAt
        self.lastStatus = ""
        self.nearHomeSince = nil

        Task { [weak self] in
            let home = try? await self?.apiService.getHome()
            self?.home = home ?? nil
        }

        if !locationManager.isTracking {
            locationManager.startTracking(nightId: nightId)
        }

        startOrReuseActivity(nightId: nightId, title: title, startedAt: startedAt)
    }

    /// Reconciles local state with the server's list of active Nights.
    /// Catches the case where the Lock Screen Live Activity's End Night
    /// button ended things while this process wasn't running - that
    /// button ends the Night on the backend directly (it runs in the
    /// widget extension, not here), so the app finds out only once it's
    /// foregrounded again and asks.
    func reconcile(activeNightIds: Set<String>) {
        guard let nightId,
              !activeNightIds.contains(nightId),
              !isEndingNight
        else { return }

        locationManager.stopTracking()
        endActivity(nightId: nightId)
        self.nightId = nil
        lastStatus = ""
    }

    func endManually() {
        guard let nightId, !isEndingNight else { return }
        end(nightId: nightId)
    }

    private func checkAutoEnd(_ location: CLLocation?) {
        guard Self.autoEndAtHomeEnabled,
              !isEndingNight,
              let nightId,
              let location,
              let home
        else {
            nearHomeSince = nil
            return
        }

        let atHome = location.distance(from: home.location)
            <= home.radius_meters

        guard atHome else {
            nearHomeSince = nil
            return
        }

        if nearHomeSince == nil {
            nearHomeSince = Date()
        } else if Date().timeIntervalSince(nearHomeSince ?? Date()) >= 90 {
            lastStatus = String(localized: "You're home — wrapping up the Night.")
            end(nightId: nightId)
        }
    }

    private func end(nightId: String) {
        isEndingNight = true
        lastStatus = String(localized: "Finishing your recap...")
        locationManager.stopTracking()

        Task {
            do {
                try await apiService.endNight(nightId: nightId)

                await MainActor.run {
                    isEndingNight = false
                    lastStatus = String(localized: "Recap generated")

                    let awayFromHome: Bool = {
                        guard let home = self.home,
                              let loc = self.locationManager.lastLocation
                        else { return true }
                        return loc.distance(from: home.location)
                            > home.radius_meters
                    }()

                    let offerSafeWalk = Self.getHomeSafeEnabled
                        && self.home != nil
                        && awayFromHome

                    self.nightId = nil
                    endActivity(nightId: nightId)

                    if offerSafeWalk, let home = self.home {
                        pendingSafeWalkHome = home
                    }
                }
            } catch {
                await MainActor.run {
                    isEndingNight = false
                    lastStatus = String(localized: "Could not end Night:")
                        + " \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Lock Screen Live Activity

    private func startOrReuseActivity(
        nightId: String, title: String, startedAt: Date
    ) {
        let authInfo = ActivityAuthorizationInfo()
        print("[LiveActivity] areActivitiesEnabled =", authInfo.areActivitiesEnabled)
        print("[LiveActivity] frequentPushesEnabled =", authInfo.frequentPushesEnabled)

        guard authInfo.areActivitiesEnabled else {
            print("[LiveActivity] Skipping request - Activities are not enabled.")
            return
        }

        let state = NightActivityAttributes.ContentState(
            nightTitle: title, startedAt: startedAt
        )

        print(
            "[LiveActivity] Existing activities:",
            Activity<NightActivityAttributes>.activities.map(\.attributes.nightId)
        )

        if let existing = Activity<NightActivityAttributes>.activities.first(
            where: { $0.attributes.nightId == nightId }
        ) {
            print("[LiveActivity] Reusing existing activity for", nightId)
            Task {
                await existing.update(
                    ActivityContent(state: state, staleDate: nil)
                )
            }
            return
        }

        do {
            let activity = try Activity.request(
                attributes: NightActivityAttributes(nightId: nightId),
                content: ActivityContent(state: state, staleDate: nil)
            )
            print(
                "[LiveActivity] Requested successfully. id =", activity.id,
                "activityState =", activity.activityState
            )
        } catch {
            // Live Activities are a nice-to-have; never block the Night
            // itself on this (e.g. the user may have them disabled) -
            // but do surface it loudly in the console so it's not a
            // silent mystery during development.
            print("[LiveActivity] Activity.request FAILED:", error)
        }
    }

    private func endActivity(nightId: String) {
        Task {
            for activity in Activity<NightActivityAttributes>.activities
            where activity.attributes.nightId == nightId {
                var endedState = activity.content.state
                endedState.isEnded = true

                // Same "Night Ended" confirmation as the Lock Screen
                // button's own end path (EndNightIntent), so it looks
                // the same regardless of which one someone used.
                await activity.end(
                    ActivityContent(state: endedState, staleDate: nil),
                    dismissalPolicy: .after(Date().addingTimeInterval(8))
                )
            }
        }
    }

    private static var autoEndAtHomeEnabled: Bool {
        if UserDefaults.standard.object(forKey: "autoEndAtHome") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "autoEndAtHome")
    }

    private static var getHomeSafeEnabled: Bool {
        UserDefaults.standard.bool(forKey: "getHomeSafeEnabled")
    }
}

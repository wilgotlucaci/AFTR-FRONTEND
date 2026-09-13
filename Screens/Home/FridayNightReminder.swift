import Foundation
import UserNotifications

/// A gentle weekly nudge rather than waiting for someone to remember to
/// open the app - "ready for tonight?" on Friday evening. Feature 3/6 of
/// the growth batch (see aftr-tracking-feature-ideas memory / the
/// session that scoped this).
enum FridayNightReminder {
    private static let identifier = "friday-night-reminder"

    static func setEnabled(_ enabled: Bool) {
        if enabled {
            Task { await schedule() }
        } else {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(
                    withIdentifiers: [identifier]
                )
        }
    }

    private static func schedule() async {
        let center = UNUserNotificationCenter.current()

        let granted = (try? await center.requestAuthorization(
            options: [.alert, .sound, .badge]
        )) ?? false

        guard granted else {
            print("[FridayNightReminder] Notification permission denied.")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Ready for tonight?")
        content.body = String(
            localized: "It's Friday. Start a Night and let AFTR remember the rest."
        )
        content.sound = .default

        // weekday: 1 = Sunday ... 6 = Friday, per Foundation's Gregorian
        // calendar numbering.
        var dateComponents = DateComponents()
        dateComponents.weekday = 6
        dateComponents.hour = 18
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("[FridayNightReminder] Failed to schedule:", error)
        }
    }
}

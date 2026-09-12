import ActivityKit
import AppIntents
import Auth
import Foundation
import os
import Supabase

/// Bare `print()` from code invoked by the system's BackgroundShortcutRunner
/// (which is what actually hosts a Live Activity button's intent when the
/// phone is locked) does not reliably reach the unified log - `os.Logger`
/// does, so use it for anything we need to see in Console.app.
private let logger = Logger(subsystem: "com.wilgot.AFTR.AFTRWidgets", category: "EndNightIntent")

/// Runs when the "End Night" button on the Lock Screen / Dynamic Island
/// is tapped. As a `LiveActivityIntent` this executes right in the widget
/// extension's process - the app is never opened, so ending a Night stays
/// exactly one tap, no unlocking-and-waiting required.
///
/// The extension has its own copy of the signed-in session (shared via a
/// Keychain access group - see `WidgetSupabase`), so it can call the
/// backend directly. The main app reconciles itself (stops location
/// tracking, clears its local "night active" state) the next time it's
/// foregrounded - see `NightSession.reconcile`.
struct EndNightIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Night"

    @Parameter(title: "Night ID")
    var nightId: String

    static var parameterSummary: some ParameterSummary {
        Summary("End Night")
    }

    init() {
        nightId = ""
    }

    init(nightId: String) {
        self.nightId = nightId
    }

    func perform() async throws -> some IntentResult {
        logger.notice("perform() called. nightId = \(nightId, privacy: .public)")
        // Update the Live Activity FIRST. The network call afterward can
        // take an unpredictable amount of time (or the extension's
        // execution window can be cut short by the system before it gets
        // there) - the user-visible confirmation must not depend on it
        // finishing. Ending the backend Night is still awaited below so
        // the request is actually sent before perform() returns.
        await dismissActivity()
        await endOnBackend()
        logger.notice("perform() finished.")
        return .result()
    }

    private func endOnBackend() async {
        do {
            let session = try await WidgetSupabase.client.auth.session
            logger.notice("Got session. userId = \(session.user.id.uuidString, privacy: .public)")

            let lang = Locale.current.language.languageCode?.identifier ?? "en"

            guard var components = URLComponents(
                string: "\(SharedConfig.apiBaseURL)/nights/\(nightId)/end"
            ) else {
                logger.error("Bad URL components.")
                return
            }

            components.queryItems = [URLQueryItem(name: "lang", value: lang)]

            guard let url = components.url else {
                logger.error("Bad URL.")
                return
            }

            logger.notice("POSTing to \(url.absoluteString, privacy: .public)")

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(
                "Bearer \(session.accessToken)",
                forHTTPHeaderField: "Authorization"
            )

            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            logger.notice("Response status = \(status, privacy: .public) body = \(body, privacy: .public)")
        } catch {
            logger.error("endOnBackend FAILED: \(String(describing: error), privacy: .public)")
        }
    }

    private func dismissActivity() async {
        // When the Lock Screen button is tapped, the system spawns a fresh
        // instance of the extension process just to run this intent. That
        // process's local ActivityKit state hasn't synced from the system
        // yet at the instant it's launched, so Activity<T>.activities can
        // come back empty on the first read even though the activity is
        // very much still running - poll briefly until it shows up.
        var activities = Activity<NightActivityAttributes>.activities
        var attempt = 0
        while activities.isEmpty && attempt < 10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            activities = Activity<NightActivityAttributes>.activities
            attempt += 1
        }

        logger.notice(
            "Activities visible to extension after \(attempt, privacy: .public) retries: \(activities.map(\.attributes.nightId), privacy: .public)"
        )

        guard !activities.isEmpty else {
            logger.error("Still no activities visible in this process after retrying - Activity<NightActivityAttributes>.activities stayed empty.")
            return
        }

        for activity in activities
        where activity.attributes.nightId == nightId {
            var endedState = activity.content.state
            endedState.isEnded = true

            logger.notice("Ending activity \(activity.id, privacy: .public), state before end: \(String(describing: activity.activityState), privacy: .public)")

            // Show the "Night Ended" confirmation for a few seconds
            // rather than either vanishing instantly or looking stuck.
            await activity.end(
                ActivityContent(state: endedState, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(8))
            )
            logger.notice("Ended activity \(activity.id, privacy: .public)")
        }
    }
}

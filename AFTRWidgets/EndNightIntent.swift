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
/// This intentionally does NOT try to touch the Live Activity object
/// itself (no `Activity<T>.activities` / `.activityUpdates` lookups).
/// Both were tried and confirmed broken in this exact execution context
/// on-device: `.activities` never populates (stays empty even after
/// seconds of retrying), and `.activityUpdates` doesn't respond to task
/// cancellation, which made `perform()` hang indefinitely and wedged the
/// Lock Screen's own unlock gesture along with it. Ending the Night on
/// the backend is the one part that's reliably fast and safe here - the
/// main app's own `NightSession.reconcile` picks up the change and ends
/// the Live Activity correctly (from the main app's process, where
/// `Activity<T>.activities` works fine) the next time it's foregrounded.
///
/// The extension has its own copy of the signed-in session (shared via a
/// Keychain access group - see `WidgetSupabase`), so it can call the
/// backend directly.
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
}

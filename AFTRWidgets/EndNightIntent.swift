import ActivityKit
import AppIntents
import Auth
import Foundation
import Supabase

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
        print("🔴 [EndNightIntent] perform() called. nightId =", nightId)
        // Update the Live Activity FIRST. The network call afterward can
        // take an unpredictable amount of time (or the extension's
        // execution window can be cut short by the system before it gets
        // there) - the user-visible confirmation must not depend on it
        // finishing. Ending the backend Night is still awaited below so
        // the request is actually sent before perform() returns.
        await dismissActivity()
        await endOnBackend()
        print("🔴 [EndNightIntent] perform() finished.")
        return .result()
    }

    private func endOnBackend() async {
        do {
            let session = try await WidgetSupabase.client.auth.session
            print("🔴 [EndNightIntent] Got session. userId =", session.user.id)

            let lang = Locale.current.language.languageCode?.identifier ?? "en"

            guard var components = URLComponents(
                string: "\(SharedConfig.apiBaseURL)/nights/\(nightId)/end"
            ) else {
                print("🔴 [EndNightIntent] Bad URL components.")
                return
            }

            components.queryItems = [URLQueryItem(name: "lang", value: lang)]

            guard let url = components.url else {
                print("🔴 [EndNightIntent] Bad URL.")
                return
            }

            print("🔴 [EndNightIntent] POSTing to", url.absoluteString)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(
                "Bearer \(session.accessToken)",
                forHTTPHeaderField: "Authorization"
            )

            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("🔴 [EndNightIntent] Response status =", status, "body =", body)
        } catch {
            print("🔴 [EndNightIntent] endOnBackend FAILED:", error)
        }
    }

    private func dismissActivity() async {
        let activities = Activity<NightActivityAttributes>.activities
        print(
            "🔴 [EndNightIntent] Activities visible to extension:",
            activities.map(\.attributes.nightId)
        )

        for activity in activities
        where activity.attributes.nightId == nightId {
            var endedState = activity.content.state
            endedState.isEnded = true

            // Show the "Night Ended" confirmation for a few seconds
            // rather than either vanishing instantly or looking stuck.
            await activity.end(
                ActivityContent(state: endedState, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(8))
            )
            print("🔴 [EndNightIntent] Ended activity", activity.id)
        }
    }
}

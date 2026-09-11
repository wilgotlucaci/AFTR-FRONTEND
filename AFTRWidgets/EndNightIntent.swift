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

    init() {
        nightId = ""
    }

    init(nightId: String) {
        self.nightId = nightId
    }

    func perform() async throws -> some IntentResult {
        await endOnBackend()
        await dismissActivity()
        return .result()
    }

    private func endOnBackend() async {
        guard let session = try? await WidgetSupabase.client.auth.session else {
            return
        }

        let lang = Locale.current.language.languageCode?.identifier ?? "en"

        guard var components = URLComponents(
            string: "\(SharedConfig.apiBaseURL)/nights/\(nightId)/end"
        ) else { return }

        components.queryItems = [URLQueryItem(name: "lang", value: lang)]

        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(session.accessToken)",
            forHTTPHeaderField: "Authorization"
        )

        _ = try? await URLSession.shared.data(for: request)
    }

    private func dismissActivity() async {
        for activity in Activity<NightActivityAttributes>.activities
        where activity.attributes.nightId == nightId {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

import ActivityKit
import Foundation

/// Shared between the app and the AFTRWidgets extension: describes the
/// Lock Screen / Dynamic Island Live Activity shown while a Night is
/// active. This file is compiled into BOTH targets (see project.pbxproj).
struct NightActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var nightTitle: String
        var startedAt: Date
    }

    var nightId: String
}

/// Config shared with the widget extension. The extension runs in its own
/// process and has no access to the app's in-memory state, so the End
/// Night button talks to Supabase and the backend directly using this.
enum SharedConfig {
    /// Keychain access group both targets share (via the Keychain Sharing
    /// entitlement) so the widget extension can read the same signed-in
    /// session the app already has.
    static let keychainAccessGroup = "5VLR7MRPZQ.com.wilgot.AFTR.shared"

    static let apiBaseURL = "https://aftr-backend.onrender.com"
    static let supabaseURL = "https://vdwpzritssipffhsbsxs.supabase.co"
    static let supabaseKey = "sb_publishable_uFSh2-phxWKDJabl3qNKjA_euxjq8Cd"
}

import Foundation
import Supabase

/// Minimal Supabase client for the widget extension process. Configured
/// with the same shared Keychain access group as the main app's
/// `SupabaseManager`, so it reads the already-signed-in session rather
/// than needing its own login.
enum WidgetSupabase {
    static let client = SupabaseClient(
        supabaseURL: URL(string: SharedConfig.supabaseURL)!,
        supabaseKey: SharedConfig.supabaseKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                storage: KeychainLocalStorage(
                    accessGroup: SharedConfig.keychainAccessGroup
                )
            )
        )
    )
}

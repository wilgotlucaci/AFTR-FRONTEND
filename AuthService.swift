import Foundation
import Supabase

final class AuthService {
    private let client = SupabaseManager.shared.client

    func signIn(
        email: String,
        password: String
    ) async throws {
        try await client.auth.signIn(
            email: email,
            password: password
        )
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    func accessToken() async throws -> String {
        let session = try await client.auth.session
        return session.accessToken
    }

    /// True if a persisted Supabase session is available (refreshing it
    /// if needed). Used on launch to skip the login screen.
    func hasValidSession() async -> Bool {
        do {
            _ = try await client.auth.session
            return true
        } catch {
            return false
        }
    }
}

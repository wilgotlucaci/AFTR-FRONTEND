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

    /// Creates the account. Returns true if a session is active
    /// immediately (email confirmation disabled), false if the user
    /// still needs to confirm via email before logging in.
    func signUp(
        email: String,
        password: String
    ) async throws -> Bool {
        try await client.auth.signUp(
            email: email,
            password: password
        )

        do {
            _ = try await client.auth.session
            return true
        } catch {
            return false
        }
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

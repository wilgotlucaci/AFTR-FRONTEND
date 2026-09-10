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

    /// Sends a 6-digit SMS code to `phone` (E.164, e.g. "+46701234567").
    /// Creates the account if it doesn't exist yet.
    func startPhoneVerification(phone: String) async throws {
        try await client.auth.signInWithOTP(phone: phone)
    }

    /// Verifies the SMS code and starts a session.
    func verifyPhone(phone: String, code: String) async throws {
        _ = try await client.auth.verifyOTP(
            phone: phone,
            token: code,
            type: .sms
        )
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

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

    func accessToken() async throws -> String {
        let session = try await client.auth.session
        return session.accessToken
    }
}

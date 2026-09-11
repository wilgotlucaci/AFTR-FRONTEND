import SwiftUI
import AuthenticationServices
import CryptoKit

/// "Continue with Apple" - native Sign in with Apple wired to Supabase.
/// On success it creates/loads the AFTR user row and flips `isLoggedIn`.
struct AppleSignInButton: View {
    @Binding var isLoggedIn: Bool

    @State private var currentNonce = ""
    @State private var isWorking = false
    @State private var errorText = ""

    private let authService = AuthService()
    private let apiService = APIService()

    var body: some View {
        VStack(spacing: 8) {
            SignInWithAppleButton(.continue) { request in
                let nonce = Self.randomNonceString()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = Self.sha256(nonce)
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(.whiteOutline)
            .clipShape(RoundedRectangle(cornerRadius: 17))
            .opacity(isWorking ? 0.55 : 1)
            .allowsHitTesting(!isWorking)

            if !errorText.isEmpty {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func handle(
        _ result: Result<ASAuthorization, Error>
    ) {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled {
                return
            }
            errorText = error.localizedDescription

        case .success(let authorization):
            guard
                let credential = authorization.credential
                    as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                errorText = String(
                    localized: "Apple didn't return a usable token."
                )
                return
            }

            let name = Self.displayName(from: credential.fullName)
            let nonce = currentNonce

            isWorking = true
            errorText = ""

            Task {
                do {
                    try await authService.signInWithApple(
                        idToken: idToken,
                        nonce: nonce
                    )
                    try await apiService.register(name: name)

                    await MainActor.run {
                        isWorking = false
                        isLoggedIn = true
                    }
                } catch {
                    await MainActor.run {
                        isWorking = false
                        errorText = error.localizedDescription
                    }
                }
            }
        }
    }

    private static func displayName(
        from components: PersonNameComponents?
    ) -> String {
        guard let components else { return "" }
        let formatted = PersonNameComponentsFormatter()
            .string(from: components)
            .trimmingCharacters(in: .whitespaces)
        return formatted
    }

    private static func randomNonceString(length: Int = 32) -> String {
        let charset = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        )
        var result = ""
        var remaining = length

        while remaining > 0 {
            let bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
            for byte in bytes where remaining > 0 {
                if Int(byte) < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

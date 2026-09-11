import SwiftUI

struct SignUpView: View {
    @Binding var isLoggedIn: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var status = ""
    @State private var isError = false
    @State private var isLoading = false
    @State private var showPassword = false

    private let authService = AuthService()
    private let apiService = APIService()

    private let neonPink = Color(
        red: 1.0,
        green: 0.10,
        blue: 0.58
    )

    private let softPink = Color(
        red: 1.0,
        green: 0.32,
        blue: 0.72
    )

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()

                heroSection

                Spacer()
                    .frame(height: 46)

                form

                appleDivider

                AppleSignInButton(isLoggedIn: $isLoggedIn)
                    .frame(height: 56)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 0) {
                        Text("Already have an account?  ")
                            .foregroundStyle(Color.white.opacity(0.45))
                        Text("Log in")
                            .foregroundStyle(softPink)
                    }
                    .font(.footnote)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
    }

    private var appleDivider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            Text("or")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.4))
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
        }
        .padding(.vertical, 16)
    }

    private var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [
                    neonPink.opacity(0.28),
                    Color.purple.opacity(0.14),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 380
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    neonPink.opacity(0.22),
                    Color.purple.opacity(0.08),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 340
            )
            .ignoresSafeArea()
        }
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            aftrLogo

            Text("Create your AFTR")
                .font(
                    .system(
                        size: 28,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)

            Text("One account. Every night remembered.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
    }

    private var aftrLogo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [softPink, neonPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 11, height: 42)
                .rotationEffect(.degrees(32))
                .offset(x: -11)

            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [softPink, neonPink],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .frame(width: 11, height: 42)
                .rotationEffect(.degrees(-32))
                .offset(x: 11)
        }
        .frame(width: 60, height: 48)
        .shadow(color: neonPink.opacity(0.55), radius: 10)
    }

    private var form: some View {
        VStack(spacing: 14) {
            field(
                label: "NAME",
                systemImage: "person",
                text: $name,
                prompt: "Your name"
            )
            .textInputAutocapitalization(.words)

            field(
                label: "EMAIL",
                systemImage: "envelope",
                text: $email,
                prompt: "Email"
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.emailAddress)

            passwordField

            Button {
                signUp()
            } label: {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView().tint(.black)
                    }

                    Group {
                        if isLoading {
                            Text("Creating…")
                        } else {
                            Text("Create account")
                        }
                    }
                    .font(.system(size: 17, weight: .semibold))

                    if !isLoading {
                        Image(systemName: "arrow.right")
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.white, softPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 17))
                .shadow(color: neonPink.opacity(0.18), radius: 12)
            }
            .disabled(isLoading)

            if !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(isError ? .red : .green)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func field(
        label: LocalizedStringKey,
        systemImage: String,
        text: Binding<String>,
        prompt: LocalizedStringKey
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.45))

            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.white.opacity(0.50))

                TextField(
                    "",
                    text: text,
                    prompt: Text(prompt)
                        .foregroundStyle(Color.white.opacity(0.48))
                )
                .foregroundStyle(.white)
                .tint(neonPink)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color.white.opacity(0.075))
            .clipShape(RoundedRectangle(cornerRadius: 17))
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(neonPink.opacity(0.16), lineWidth: 1)
            }
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PASSWORD")
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.45))

            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .foregroundStyle(Color.white.opacity(0.50))

                Group {
                    if showPassword {
                        TextField(
                            "",
                            text: $password,
                            prompt: Text("At least 6 characters")
                                .foregroundStyle(Color.white.opacity(0.48))
                        )
                    } else {
                        SecureField(
                            "",
                            text: $password,
                            prompt: Text("At least 6 characters")
                                .foregroundStyle(Color.white.opacity(0.48))
                        )
                    }
                }
                .foregroundStyle(.white)
                .tint(neonPink)

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(Color.white.opacity(0.50))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color.white.opacity(0.075))
            .clipShape(RoundedRectangle(cornerRadius: 17))
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(neonPink.opacity(0.16), lineWidth: 1)
            }
        }
    }

    private func signUp() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            fail(String(localized: "Enter your name."))
            return
        }
        guard email.contains("@") else {
            fail(String(localized: "Enter a valid email."))
            return
        }
        guard password.count >= 6 else {
            fail(String(localized: "Password needs at least 6 characters."))
            return
        }

        isLoading = true
        status = ""

        Task {
            do {
                let hasSession = try await authService.signUp(
                    email: email,
                    password: password
                )

                guard hasSession else {
                    await MainActor.run {
                        isLoading = false
                        isError = false
                        status = String(
                            localized: "Account created. Check your email to confirm, then log in."
                        )
                    }
                    return
                }

                try await apiService.register(name: trimmedName)

                await MainActor.run {
                    isLoading = false
                    isLoggedIn = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    fail(error.localizedDescription)
                }
            }
        }
    }

    private func fail(_ message: String) {
        isError = true
        status = message
    }
}

#Preview {
    SignUpView(isLoggedIn: .constant(false))
}

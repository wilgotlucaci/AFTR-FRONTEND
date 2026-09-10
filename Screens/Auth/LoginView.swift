import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var status = ""
    @State private var isLoading = false
    @State private var showPassword = false

    private let authService = AuthService()

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
                    .frame(height: 52)

                loginForm

                Spacer()

                footer
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
    }

    private var background: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

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

            LinearGradient(
                colors: [
                    Color.clear,
                    neonPink.opacity(0.035),
                    Color.black.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            aftrLogo

            Text("AFTR")
                .font(
                    .system(
                        size: 46,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .tracking(-1)

            VStack(spacing: 3) {
                Text("Live tonight.")
                Text("Remember tomorrow.")
            }
            .font(
                .system(
                    size: 16,
                    weight: .medium
                )
            )
            .foregroundStyle(
                Color.white.opacity(0.60)
            )
            .multilineTextAlignment(.center)

            RoundedRectangle(
                cornerRadius: 20
            )
            .fill(
                LinearGradient(
                    colors: [
                        neonPink,
                        softPink
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(
                width: 54,
                height: 3
            )
            .padding(.top, 6)
            .shadow(
                color: neonPink.opacity(0.65),
                radius: 8
            )
        }
    }

    private var aftrLogo: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: 5
            )
            .fill(
                LinearGradient(
                    colors: [
                        softPink,
                        neonPink
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(
                width: 11,
                height: 42
            )
            .rotationEffect(.degrees(32))
            .offset(x: -11)

            RoundedRectangle(
                cornerRadius: 5
            )
            .fill(
                LinearGradient(
                    colors: [
                        softPink,
                        neonPink
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            )
            .frame(
                width: 11,
                height: 42
            )
            .rotationEffect(.degrees(-32))
            .offset(x: 11)
        }
        .frame(
            width: 60,
            height: 48
        )
        .shadow(
            color: neonPink.opacity(0.55),
            radius: 10
        )
    }

    private var loginForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("EMAIL")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(
                        Color.white.opacity(0.45)
                    )

                HStack(spacing: 12) {
                    Image(
                        systemName: "envelope"
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.50)
                    )

                    TextField(
                        "",
                        text: $email,
                        prompt: Text("Email")
                            .foregroundStyle(
                                Color.white.opacity(0.48)
                            )
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .foregroundStyle(.white)
                    .tint(neonPink)
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(
                    Color.white.opacity(0.075)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 17
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 17
                    )
                    .stroke(
                        neonPink.opacity(0.16),
                        lineWidth: 1
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("PASSWORD")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(
                        Color.white.opacity(0.45)
                    )

                HStack(spacing: 12) {
                    Image(
                        systemName: "lock"
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.50)
                    )

                    Group {
                        if showPassword {
                            TextField(
                                "",
                                text: $password,
                                prompt: Text("Password")
                                    .foregroundStyle(
                                        Color.white.opacity(0.48)
                                    )
                            )
                        } else {
                            SecureField(
                                "",
                                text: $password,
                                prompt: Text("Password")
                                    .foregroundStyle(
                                        Color.white.opacity(0.48)
                                    )
                            )
                        }
                    }
                    .foregroundStyle(.white)
                    .tint(neonPink)

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(
                            systemName:
                                showPassword
                                ? "eye.slash"
                                : "eye"
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.50)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(
                    Color.white.opacity(0.075)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 17
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 17
                    )
                    .stroke(
                        neonPink.opacity(0.16),
                        lineWidth: 1
                    )
                }
            }

            Button {
                signIn()
            } label: {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    }

                    Text(
                        isLoading
                            ? "Logging in..."
                            : "Log in"
                    )
                    .font(
                        .system(
                            size: 17,
                            weight: .semibold
                        )
                    )

                    if !isLoading {
                        Image(
                            systemName: "arrow.right"
                        )
                        .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [
                            Color.white,
                            softPink
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.black)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 17
                    )
                )
                .shadow(
                    color: neonPink.opacity(0.18),
                    radius: 12
                )
            }
            .disabled(isLoading)

            if !status.isEmpty {
                HStack(spacing: 8) {
                    Image(
                        systemName:
                            status == "Logged in"
                            ? "checkmark.circle.fill"
                            : "exclamationmark.circle.fill"
                    )

                    Text(status)
                }
                .font(.caption)
                .foregroundStyle(
                    status == "Logged in"
                        ? .green
                        : .red
                )
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(neonPink)
                    .frame(width: 5, height: 5)

                Circle()
                    .fill(softPink)
                    .frame(width: 5, height: 5)

                Circle()
                    .fill(Color.purple)
                    .frame(width: 5, height: 5)
            }

            Text("YOUR NIGHT STARTS HERE")
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.4)
                .foregroundStyle(
                    Color.white.opacity(0.28)
                )
        }
    }

    private func signIn() {
        guard !email.isEmpty else {
            status = "Enter your email."
            return
        }

        guard !password.isEmpty else {
            status = "Enter your password."
            return
        }

        isLoading = true
        status = ""

        Task {
            do {
                try await authService.signIn(
                    email: email,
                    password: password
                )

                await MainActor.run {
                    isLoading = false
                    status = "Logged in"
                    isLoggedIn = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    status = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    LoginView(
        isLoggedIn: .constant(false)
    )
}

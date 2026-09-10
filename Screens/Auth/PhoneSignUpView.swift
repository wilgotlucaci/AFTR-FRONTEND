import SwiftUI

struct PhoneSignUpView: View {
    @Binding var isLoggedIn: Bool

    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case details
        case code
    }

    @State private var step: Step = .details

    @State private var name = ""
    @State private var countryCode = "+46"
    @State private var localNumber = ""
    @State private var code = ""

    @State private var status = ""
    @State private var isError = false
    @State private var isLoading = false

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

    /// E.164, e.g. +46701234567. Drops spaces, dashes and a leading 0.
    private var e164Phone: String {
        var digits = localNumber.filter { $0.isNumber }
        if digits.hasPrefix("0") {
            digits.removeFirst()
        }
        let cc = countryCode.filter { $0 == "+" || $0.isNumber }
        return cc + digits
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()

                heroSection

                Spacer().frame(height: 44)

                if step == .details {
                    detailsForm
                } else {
                    codeForm
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 0) {
                        Text("Rather use email?  ")
                            .foregroundStyle(Color.white.opacity(0.45))
                        Text("Go back")
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

    // MARK: - Steps

    private var detailsForm: some View {
        VStack(spacing: 14) {
            field(
                label: "NAME",
                systemImage: "person",
                text: $name,
                prompt: "Your name"
            )
            .textInputAutocapitalization(.words)

            VStack(alignment: .leading, spacing: 8) {
                Text("PHONE NUMBER")
                    .font(.caption2).fontWeight(.semibold).tracking(1.2)
                    .foregroundStyle(Color.white.opacity(0.45))

                HStack(spacing: 10) {
                    TextField("", text: $countryCode)
                        .frame(width: 58)
                        .multilineTextAlignment(.center)
                        .keyboardType(.phonePad)
                        .foregroundStyle(.white)
                        .tint(neonPink)
                        .padding(.horizontal, 10)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.075))
                        .clipShape(RoundedRectangle(cornerRadius: 17))
                        .overlay {
                            RoundedRectangle(cornerRadius: 17)
                                .stroke(neonPink.opacity(0.16), lineWidth: 1)
                        }

                    HStack(spacing: 12) {
                        Image(systemName: "phone")
                            .foregroundStyle(Color.white.opacity(0.50))

                        TextField(
                            "",
                            text: $localNumber,
                            prompt: Text("70 123 45 67")
                                .foregroundStyle(Color.white.opacity(0.48))
                        )
                        .keyboardType(.phonePad)
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

            primaryButton(
                title: isLoading ? "Sending…" : "Send code",
                icon: "arrow.right"
            ) {
                sendCode()
            }

            statusLine
        }
    }

    private var codeForm: some View {
        VStack(spacing: 14) {
            Text("Enter the 6-digit code we sent to \(e164Phone).")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

            HStack(spacing: 12) {
                Image(systemName: "number")
                    .foregroundStyle(Color.white.opacity(0.50))

                TextField(
                    "",
                    text: $code,
                    prompt: Text("123456")
                        .foregroundStyle(Color.white.opacity(0.48))
                )
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .tracking(6)
                .foregroundStyle(.white)
                .tint(neonPink)
                .onChange(of: code) { _, newValue in
                    code = String(newValue.filter { $0.isNumber }.prefix(6))
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

            primaryButton(
                title: isLoading ? "Verifying…" : "Verify",
                icon: "checkmark"
            ) {
                verify()
            }

            HStack(spacing: 18) {
                Button("Resend code") { sendCode() }
                Button("Change number") {
                    code = ""
                    status = ""
                    step = .details
                }
            }
            .font(.caption)
            .foregroundStyle(softPink)
            .disabled(isLoading)

            statusLine
        }
    }

    // MARK: - Shared bits

    private var statusLine: some View {
        Group {
            if !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(isError ? .red : .green)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func primaryButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(.black)
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                if !isLoading {
                    Image(systemName: icon).font(.subheadline)
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
    }

    private func field(
        label: String,
        systemImage: String,
        text: Binding<String>,
        prompt: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption2).fontWeight(.semibold).tracking(1.2)
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

            Text(step == .details ? "Sign up with phone" : "Check your messages")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(
                step == .details
                    ? "We'll text you a code to confirm it's you."
                    : "It can take a few seconds to arrive."
            )
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

    // MARK: - Actions

    private func sendCode() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            fail("Enter your name.")
            return
        }
        guard e164Phone.count >= 8 else {
            fail("Enter a valid phone number.")
            return
        }

        isLoading = true
        status = ""

        Task {
            do {
                try await authService.startPhoneVerification(
                    phone: e164Phone
                )
                await MainActor.run {
                    isLoading = false
                    isError = false
                    status = ""
                    step = .code
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    fail(error.localizedDescription)
                }
            }
        }
    }

    private func verify() {
        guard code.count == 6 else {
            fail("Enter the 6-digit code.")
            return
        }

        isLoading = true
        status = ""

        Task {
            do {
                try await authService.verifyPhone(
                    phone: e164Phone,
                    code: code
                )
                try await apiService.register(
                    name: name.trimmingCharacters(in: .whitespaces)
                )
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
    PhoneSignUpView(isLoggedIn: .constant(false))
}

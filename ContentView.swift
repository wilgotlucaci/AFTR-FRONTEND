import SwiftUI

struct ContentView: View {
    @State private var isCheckingSession = true
    @State private var isLoggedIn = false

    @State private var activeNightId = ""
    @State private var activeNightTitle = ""

    private let authService = AuthService()

    var body: some View {
        Group {
            if isCheckingSession {
                SplashView()
            } else if !isLoggedIn {
                LoginView(
                    isLoggedIn: $isLoggedIn
                )
            } else if activeNightId.isEmpty {
                HomeView(
                    activeNightId: $activeNightId,
                    activeNightTitle: $activeNightTitle,
                    isLoggedIn: $isLoggedIn
                )
            } else {
                ActiveNightView(
                    nightId: activeNightId,
                    nightTitle: activeNightTitle,
                    activeNightId: $activeNightId
                )
            }
        }
        .task {
            isLoggedIn = await authService.hasValidSession()
            isCheckingSession = false
        }
    }
}

private struct SplashView: View {
    private let neonPink = Color(
        red: 1.0,
        green: 0.10,
        blue: 0.58
    )

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("AFTR")
                    .font(
                        .system(
                            size: 42,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)

                ProgressView()
                    .tint(neonPink)
            }
        }
    }
}

#Preview {
    ContentView()
}

import SwiftUI

struct ContentView: View {
    @State private var isCheckingSession = true
    @State private var isLoggedIn = false

    @StateObject private var session = NightSession()

    private let authService = AuthService()

    var body: some View {
        Group {
            if isCheckingSession {
                SplashView()
            } else if !isLoggedIn {
                LoginView(
                    isLoggedIn: $isLoggedIn
                )
            } else {
                HomeView(isLoggedIn: $isLoggedIn)
                    .environmentObject(session)
            }
        }
        .task {
            isLoggedIn = await authService.hasValidSession()
            isCheckingSession = false
        }
        // Lives at the root so "get home safe" can be offered after a
        // Night ends no matter which screen the user happens to be on.
        .fullScreenCover(
            isPresented: Binding(
                get: { session.pendingSafeWalkHome != nil },
                set: { isPresented in
                    if !isPresented {
                        session.pendingSafeWalkHome = nil
                    }
                }
            )
        ) {
            if let home = session.pendingSafeWalkHome {
                SafeWalkView(home: home) {
                    session.pendingSafeWalkHome = nil
                }
            }
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

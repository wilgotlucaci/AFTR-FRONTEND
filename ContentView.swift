import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false

    @State private var activeNightId = ""
    @State private var activeNightTitle = ""

    var body: some View {
        Group {
            if !isLoggedIn {
                LoginView(
                    isLoggedIn: $isLoggedIn
                )
            } else if activeNightId.isEmpty {
                HomeView(
                    activeNightId: $activeNightId,
                    activeNightTitle: $activeNightTitle
                )
            } else {
                ActiveNightView(
                    nightId: activeNightId,
                    nightTitle: activeNightTitle,
                    activeNightId: $activeNightId
                )
            }
        }
    }
}

#Preview {
    ContentView()
}

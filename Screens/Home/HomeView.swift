import SwiftUI

struct HomeView: View {
    @State private var nightTitle = "Friday Night"
    @State private var isStartingNight = false
    @State private var status = ""

    @State private var nights: [NightSummary] = []
    @State private var isLoadingNights = false
    @State private var selectedNight: NightSummary?

    @State private var joinCode = ""
    @State private var isJoiningNight = false

    private enum Field {
        case nightTitle
        case joinCode
    }
    @FocusState private var focusedField: Field?

    @State private var showWrap = false
    @State private var showSettings = false
    @State private var showActiveNight = false

    @EnvironmentObject private var session: NightSession
    @Binding var isLoggedIn: Bool

    private let apiService = APIService()
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

            if let selectedNight {
                RecapView(
                    nightId: selectedNight.id,
                    onBack: { self.selectedNight = nil }
                )

            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header

                        welcomeSection

                        if session.isActive {
                            activeNightCard
                        } else {
                            startNightCard

                            joinNightCard
                        }

                        quickOverviewSection

                        Button {
                            showWrap = true
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Your month in review")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(
                                LinearGradient(
                                    colors: [
                                        neonPink.opacity(0.14),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }

                        recentNightsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .overlay(alignment: .top) { statusBarScrim }
            }
        }
        .task {
            await loadNights()
        }
        .sheet(isPresented: $showWrap) {
            MonthlyWrapView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isLoggedIn: $isLoggedIn)
        }
        .fullScreenCover(isPresented: $showActiveNight) {
            ActiveNightView(session: session)
        }
    }

    /// Sits exactly where `startNightCard` normally does - once a Night
    /// is active there's no separate top banner to fight with scroll
    /// overscroll/safe-area edge cases, just this in the same slot.
    private var activeNightCard: some View {
        Button {
            showActiveNight = true
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 7, height: 7)
                                .shadow(color: .green.opacity(0.7), radius: 3)

                            Text("NIGHT ACTIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .tracking(1.3)
                                .foregroundStyle(neonPink)
                        }

                        Text(session.nightTitle)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 25))
                        .foregroundStyle(neonPink)
                        .shadow(
                            color: neonPink.opacity(0.55),
                            radius: 8
                        )
                }

                HStack(alignment: .center) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(elapsed(session.startedAt, context.date))
                            .font(
                                .system(
                                    size: 30,
                                    weight: .bold,
                                    design: .rounded
                                )
                                .monospacedDigit()
                            )
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Text("View Night")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right")
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(
                        LinearGradient(
                            colors: [.white, softPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [
                        neonPink.opacity(0.16),
                        Color.white.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 22)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(neonPink.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func elapsed(_ start: Date, _ now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private var statusBarScrim: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color.black.opacity(0.92),
                Color.black.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 60)
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }

    private var background: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    neonPink.opacity(0.18),
                    Color.purple.opacity(0.08),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    neonPink.opacity(0.10),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 340
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                aftrLogo

                Text("AFTR")
                    .font(
                        .system(
                            size: 25,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
            }

            Spacer()

            Menu {
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                Button(role: .destructive) {
                    signOut()
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 27))
                    .foregroundStyle(
                        Color.white.opacity(0.85)
                    )
            }
        }
    }

    private var aftrLogo: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: 3
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
            .frame(width: 7, height: 26)
            .rotationEffect(.degrees(32))
            .offset(x: -7)

            RoundedRectangle(
                cornerRadius: 3
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
            .frame(width: 7, height: 26)
            .rotationEffect(.degrees(-32))
            .offset(x: 7)
        }
        .frame(width: 36, height: 30)
        .shadow(
            color: neonPink.opacity(0.4),
            radius: 6
        )
    }

    /// Two mugs clinking - the "recap ready" mark for a finished Night.
    /// No SF Symbol matches "cheers", so this is hand-drawn to match the
    /// app's own vector marks (see `aftrLogo`).
    private func cheersIcon(color: Color) -> some View {
        HStack(spacing: -2) {
            beerMug(color: color)
                .rotationEffect(.degrees(-18))
                .offset(y: 1)
            beerMug(color: color)
                .rotationEffect(.degrees(18))
                .offset(y: 1)
        }
        .shadow(color: color.opacity(0.5), radius: 5)
    }

    private func beerMug(color: Color) -> some View {
        VStack(spacing: 1) {
            Capsule()
                .fill(color)
                .frame(width: 11, height: 3.5)

            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(color, lineWidth: 1.4)
                    )
                    .frame(width: 11, height: 13)

                RoundedRectangle(cornerRadius: 2.5)
                    .stroke(color, lineWidth: 1.4)
                    .frame(width: 5, height: 7.5)
                    .offset(x: 7.5)
            }
        }
    }

    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Ready for tonight?")
                .font(
                    .system(
                        size: 33,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)

            Text(
                "Start a Night and AFTR will quietly remember the rest."
            )
            .font(.subheadline)
            .foregroundStyle(
                Color.white.opacity(0.50)
            )
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
        .padding(.top, 6)
    }

    private var startNightCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("START A NIGHT")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .tracking(1.3)
                        .foregroundStyle(
                            neonPink.opacity(0.9)
                        )

                    Text("Make tonight memorable.")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 25))
                    .foregroundStyle(neonPink)
                    .shadow(
                        color: neonPink.opacity(0.55),
                        radius: 8
                    )
            }

            TextField(
                "",
                text: $nightTitle,
                prompt: Text("Night title")
                    .foregroundStyle(
                        Color.white.opacity(0.40)
                    )
            )
            .foregroundStyle(.white)
            .tint(neonPink)
            .focused($focusedField, equals: .nightTitle)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(
                Color.black.opacity(0.35)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 16
                )
                .stroke(
                    neonPink.opacity(0.14),
                    lineWidth: 1
                )
            }

            Button {
                startNight()
            } label: {
                HStack(spacing: 9) {
                    if isStartingNight {
                        ProgressView()
                            .tint(.black)
                    }

                    Group {
                        if isStartingNight {
                            Text("Starting...")
                        } else {
                            Text("Start Night")
                        }
                    }
                    .font(
                        .system(
                            size: 17,
                            weight: .semibold
                        )
                    )

                    if !isStartingNight {
                        Image(
                            systemName: "arrow.right"
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [
                            .white,
                            softPink
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.black)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16
                    )
                )
                .shadow(
                    color: neonPink.opacity(0.16),
                    radius: 10
                )
            }
            .disabled(isStartingNight)

            if !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    neonPink.opacity(0.10),
                    Color.white.opacity(0.055)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 22
            )
            .stroke(
                neonPink.opacity(0.12),
                lineWidth: 1
            )
        }
    }

    private var joinNightCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 18))
                .foregroundStyle(softPink)

            TextField(
                "",
                text: $joinCode,
                prompt: Text("Join code")
                    .foregroundStyle(
                        Color.white.opacity(0.40)
                    )
            )
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .foregroundStyle(.white)
            .tint(neonPink)
            .focused($focusedField, equals: .joinCode)
            .onChange(of: joinCode) { _, newValue in
                joinCode = String(
                    newValue.uppercased().prefix(6)
                )
            }

            Button {
                joinWithCode()
            } label: {
                if isJoiningNight {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Join")
                        .font(
                            .system(
                                size: 15,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)
                }
            }
            .disabled(
                isJoiningNight || joinCode.count < 6
            )
            .opacity(joinCode.count < 6 ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(
            Color.white.opacity(0.05)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    Color.white.opacity(0.06),
                    lineWidth: 1
                )
        }
    }

    private var quickOverviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("YOUR AFTR")

            HStack(spacing: 10) {
                overviewCard(
                    icon: "moon.fill",
                    value: "\(finishedNightsCount)",
                    label: "Nights",
                    accent: neonPink
                )

                overviewCard(
                    icon: "clock.fill",
                    value: latestNightLabel,
                    label: "Latest",
                    accent: softPink
                )

                overviewCard(
                    icon: "sparkles",
                    value: "\(nights.count)",
                    label: "Memories",
                    accent: .purple
                )
            }
        }
    }

    private var recentNightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("RECENT NIGHTS")

                Spacer()

                if !nights.isEmpty {
                    Text("\(nights.count)")
                        .font(.caption)
                        .foregroundStyle(
                            Color.white.opacity(0.35)
                        )
                }
            }

            if isLoadingNights {
                ProgressView()
                    .tint(neonPink)
                    .frame(
                        maxWidth: .infinity
                    )
                    .padding(.vertical, 24)

            } else if nights.isEmpty {
                emptyRecentNights

            } else {
                VStack(spacing: 11) {
                    ForEach(nights) { night in
                        Button {
                            if night.status == "finished" {
                                selectedNight = night
                            }
                        } label: {
                            recentNightCard(
                                night: night
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyRecentNights: some View {
        VStack(spacing: 10) {
            Image(
                systemName: "moon.stars"
            )
            .font(.system(size: 26))
            .foregroundStyle(
                neonPink.opacity(0.65)
            )

            Text("No Nights yet")
                .font(.headline)
                .foregroundStyle(.white)

            Text(
                "Your finished Nights will appear here."
            )
            .font(.caption)
            .foregroundStyle(
                Color.white.opacity(0.4)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            Color.white.opacity(0.045)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20
            )
        )
    }

    private func recentNightCard(
        night: NightSummary
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 14
                )
                .fill(
                    LinearGradient(
                        colors: [
                            neonPink.opacity(0.18),
                            Color.purple.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: 52,
                    height: 52
                )

                if night.status == "finished" {
                    cheersIcon(color: neonPink)
                } else {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.green)
                }
            }

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(night.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Text(
                        formattedDate(
                            night.started_at
                        )
                    )

                    Text("•")

                    Group {
                        if night.status == "finished" {
                            Text("Recap ready")
                        } else {
                            Text("Active")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(
                    Color.white.opacity(0.42)
                )
            }

            Spacer()

            Image(
                systemName: "chevron.right"
            )
            .font(.caption)
            .foregroundStyle(
                Color.white.opacity(0.30)
            )
        }
        .padding(14)
        .background(
            Color.white.opacity(0.05)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 18
            )
            .stroke(
                Color.white.opacity(0.04),
                lineWidth: 1
            )
        }
    }

    private func overviewCard(
        icon: String,
        value: String,
        label: LocalizedStringKey,
        accent: Color
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(accent)

            Text(value)
                .font(
                    .system(
                        size: 18,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption2)
                .foregroundStyle(
                    Color.white.opacity(0.38)
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            Color.white.opacity(0.05)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 17
            )
        )
    }

    private func sectionTitle(
        _ title: LocalizedStringKey
    ) -> some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .tracking(1.3)
            .foregroundStyle(
                Color.white.opacity(0.42)
            )
    }

    private var finishedNightsCount: Int {
        nights.filter {
            $0.status == "finished"
        }
        .count
    }

    private var latestNightLabel: String {
        guard let firstNight = nights.first else {
            return "—"
        }

        return formattedShortDate(
            firstNight.started_at
        )
    }

    private func formattedDate(
        _ dateString: String
    ) -> String {
        guard let date = ISO8601DateFormatter.aftrDate(from: dateString)
        else {
            return String(localized: "Night")
        }

        return date.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
        )
    }

    private func formattedShortDate(
        _ dateString: String
    ) -> String {
        guard let date = ISO8601DateFormatter.aftrDate(from: dateString)
        else {
            return "—"
        }

        return date.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
        )
    }

    private func startNight() {
        guard !nightTitle.isEmpty else {
            status = String(localized: "Enter a Night title.")
            return
        }

        focusedField = nil
        isStartingNight = true
        status = ""

        Task {
            do {
                let night =
                    try await apiService.createNight(
                        title: nightTitle
                    )

                try await apiService.joinNight(
                    nightId: night.id
                )

                await MainActor.run {
                    session.start(nightId: night.id, title: night.title)
                    showActiveNight = true
                    isStartingNight = false
                    status = ""
                }

            } catch {
                await MainActor.run {
                    isStartingNight = false
                    status =
                        error.localizedDescription
                }
            }
        }
    }

    private func joinWithCode() {
        let code = joinCode.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard code.count >= 6 else {
            status = String(localized: "Enter the 6-character join code.")
            return
        }

        focusedField = nil
        isJoiningNight = true
        status = ""

        Task {
            do {
                let night = try await apiService.joinNight(
                    code: code
                )

                await MainActor.run {
                    session.start(nightId: night.id, title: night.title)
                    showActiveNight = true
                    isJoiningNight = false
                    joinCode = ""
                }
            } catch {
                await MainActor.run {
                    isJoiningNight = false
                    status = String(
                        localized: "Could not join Night. Check the code."
                    )
                }
            }
        }
    }

    private func signOut() {
        Task {
            await authService.signOut()

            await MainActor.run {
                isLoggedIn = false
            }
        }
    }

    @MainActor
    private func loadNights() async {
        isLoadingNights = true

        do {
            nights =
                try await apiService.getNights()

            session.reconcile(
                activeNightIds: Set(
                    nights.filter { $0.status == "active" }.map(\.id)
                )
            )

            if !session.isActive,
               let ongoing = nights.first(
                   where: { $0.status == "active" }
               ) {
                let startedAt = ISO8601DateFormatter.aftrDate(
                    from: ongoing.started_at
                ) ?? Date()

                session.resume(
                    nightId: ongoing.id,
                    title: ongoing.title,
                    startedAt: startedAt
                )
            }
        } catch {
            status = String(localized: "Could not load Nights:")
                + " \(error.localizedDescription)"
        }

        isLoadingNights = false
    }
}

#Preview {
    HomeView(isLoggedIn: .constant(true))
        .environmentObject(NightSession())
}

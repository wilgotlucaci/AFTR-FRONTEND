import SwiftUI

struct ActiveNightView: View {
    let nightId: String
    let nightTitle: String

    @Binding var activeNightId: String

    @State private var isEndingNight = false
    @State private var status = ""
    @State private var startedAt = Date()

    @State private var joinCode = ""
    @State private var participantCount = 1

    @StateObject private var locationManager = LocationManager()

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
                header

                Spacer()

                mainContent

                Spacer()

                endNightButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 26)
        }
        .onAppear {
            startedAt = Date()

            if !locationManager.isTracking {
                locationManager.startTracking(
                    nightId: nightId
                )
            }
        }
        .task {
            while !Task.isCancelled {
                await refreshDetail()

                try? await Task.sleep(
                    for: .seconds(20)
                )
            }
        }
    }

    @MainActor
    private func refreshDetail() async {
        guard let detail = try? await apiService.getNight(
            nightId: nightId
        ) else {
            return
        }

        joinCode = detail.join_code ?? ""
        participantCount = max(detail.participant_count, 1)
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
                            size: 24,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
            }

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(
                        locationManager.isTracking
                            ? Color.green
                            : Color.orange
                    )
                    .frame(
                        width: 7,
                        height: 7
                    )

                Text(
                    locationManager.isTracking
                        ? "LIVE"
                        : "WAITING"
                )
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.1)
                .foregroundStyle(
                    Color.white.opacity(0.55)
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
            .frame(
                width: 7,
                height: 26
            )
            .rotationEffect(
                .degrees(32)
            )
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
            .frame(
                width: 7,
                height: 26
            )
            .rotationEffect(
                .degrees(-32)
            )
            .offset(x: 7)
        }
        .frame(
            width: 36,
            height: 30
        )
        .shadow(
            color: neonPink.opacity(0.4),
            radius: 6
        )
    }

    private var mainContent: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(
                        neonPink.opacity(0.11)
                    )
                    .frame(
                        width: 110,
                        height: 110
                    )

                Circle()
                    .stroke(
                        neonPink.opacity(0.16),
                        lineWidth: 1
                    )
                    .frame(
                        width: 110,
                        height: 110
                    )

                Image(
                    systemName: "moon.stars.fill"
                )
                .font(
                    .system(size: 38)
                )
                .foregroundStyle(neonPink)
                .shadow(
                    color: neonPink.opacity(0.7),
                    radius: 14
                )
            }

            VStack(spacing: 10) {
                Text("NIGHT ACTIVE")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(
                        neonPink.opacity(0.9)
                    )

                Text(nightTitle)
                    .font(
                        .system(
                            size: 36,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                TimelineView(
                    .periodic(
                        from: .now,
                        by: 1
                    )
                ) { context in
                    Text(
                        formattedDuration(
                            from: startedAt,
                            to: context.date
                        )
                    )
                    .font(
                        .system(
                            size: 27,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.70)
                    )
                }
            }

            trackingStatusCard

            if !joinCode.isEmpty {
                inviteCard
            }

            VStack(spacing: 7) {
                Text("Put your phone away.")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(
                    "AFTR will quietly track the night and build your recap."
                )
                .font(.subheadline)
                .foregroundStyle(
                    Color.white.opacity(0.42)
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            }

            if !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(
                        Color.white.opacity(0.45)
                    )
                    .multilineTextAlignment(.center)
            }

            if let error = locationManager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var trackingStatusCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        locationManager.isTracking
                            ? Color.green.opacity(0.12)
                            : Color.orange.opacity(0.12)
                    )
                    .frame(
                        width: 42,
                        height: 42
                    )

                Image(
                    systemName:
                        locationManager.isTracking
                        ? "location.fill"
                        : "location.slash"
                )
                .foregroundStyle(
                    locationManager.isTracking
                        ? .green
                        : .orange
                )
            }

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(
                    locationManager.isTracking
                        ? "AFTR is tracking your night"
                        : "Waiting for location permission"
                )
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)

                Text(
                    locationManager.isTracking
                        ? "You can leave the app in the background."
                        : "Location access is needed for your recap."
                )
                .font(.caption)
                .foregroundStyle(
                    Color.white.opacity(0.38)
                )
            }

            Spacer()
        }
        .padding(16)
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

    private var inviteCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("INVITE CODE")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(
                        Color.white.opacity(0.45)
                    )

                Text(joinCode)
                    .font(
                        .system(
                            size: 22,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .tracking(2)
            }

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "person.2.fill")
                    .font(.caption)

                Text("\(participantCount)")
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
            }
            .foregroundStyle(
                Color.white.opacity(0.75)
            )

            ShareLink(
                item: "Join my AFTR Night with code \(joinCode)"
            ) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(neonPink)
                    .frame(width: 38, height: 38)
                    .background(
                        neonPink.opacity(0.12)
                    )
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .background(
            Color.white.opacity(0.05)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    neonPink.opacity(0.12),
                    lineWidth: 1
                )
        }
    }

    private var endNightButton: some View {
        Button {
            endNight()
        } label: {
            HStack(spacing: 10) {
                if isEndingNight {
                    ProgressView()
                        .tint(.black)
                }

                Text(
                    isEndingNight
                        ? "Ending Night..."
                        : "End Night"
                )
                .font(
                    .system(
                        size: 17,
                        weight: .semibold
                    )
                )

                if !isEndingNight {
                    Image(
                        systemName: "stop.fill"
                    )
                    .font(.caption)
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
        .disabled(isEndingNight)
    }

    private func formattedDuration(
        from start: Date,
        to end: Date
    ) -> String {
        let seconds = max(
            0,
            Int(
                end.timeIntervalSince(
                    start
                )
            )
        )

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(
                format: "%02d:%02d:%02d",
                hours,
                minutes,
                remainingSeconds
            )
        }

        return String(
            format: "%02d:%02d",
            minutes,
            remainingSeconds
        )
    }

    private func endNight() {
        guard !isEndingNight else {
            return
        }

        isEndingNight = true
        status = "Finishing your recap..."

        locationManager.stopTracking()

        Task {
            do {
                try await apiService.endNight(
                    nightId: nightId
                )

                await MainActor.run {
                    isEndingNight = false
                    status = "Recap generated"
                    activeNightId = ""
                }

            } catch {
                await MainActor.run {
                    isEndingNight = false
                    status =
                        "Could not end Night: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    ActiveNightView(
        nightId: "test-night-id",
        nightTitle: "Friday Night",
        activeNightId: .constant(
            "test-night-id"
        )
    )
}

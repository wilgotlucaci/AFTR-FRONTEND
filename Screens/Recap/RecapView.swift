import SwiftUI
import MapKit

struct RecapView: View {
    let nightId: String
    var onBack: (() -> Void)? = nil

    @State private var recap: RecapModel?
    @State private var isLoading = true
    @State private var errorMessage = ""

    @State private var media: [NightMedia] = []
    @State private var showAddPhotos = false
    @State private var viewerStart: ViewerStart?
    @State private var selectedPage = 0

    private struct ViewerStart: Identifiable {
        let id: Int
    }

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

            if isLoading {
                loadingView
            } else if let recap {
                TabView(selection: $selectedPage) {
                    statsPage(recap).tag(0)
                    GroupRecapView(recap: recap).tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            } else {
                errorView
            }
        }
        .overlay(alignment: .top) { statusBarScrim }
        .overlay(alignment: .bottom) {
            if let recap {
                pageIndicator(recap)
            }
        }
        .task {
            await loadRecap()
            await loadMedia()
        }
        .fullScreenCover(item: $viewerStart) { start in
            PhotoViewerView(media: media, startIndex: start.id)
        }
        .sheet(isPresented: $showAddPhotos) {
            if let recap {
                AddPhotosView(
                    nightId: nightId,
                    start: parseISODate(recap.started_at) ?? Date(),
                    end: parseISODate(recap.ended_at ?? "") ?? Date(),
                    routeCoordinates: (recap.route ?? [])
                        .flatMap { $0.coordinates },
                    onDone: { Task { await loadMedia() } }
                )
            }
        }
    }

    private func statsPage(_ recap: RecapModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                heroSection(recap)

                durationCard(recap)

                quickStatsSection(recap)

                if !recap.fun_highlights.isEmpty {
                    funHighlightsSection(recap)
                }

                if hasRoute(recap) {
                    routeMapSection(recap)
                }

                if !recap.venue_timeline.isEmpty {
                    venueTimelineSection(recap)
                }

                bestMomentsSection(recap)

                movementSection(recap)

                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 50)
        }
        .scrollIndicators(.hidden)
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

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(neonPink)

            Text("Building your AFTR...")
                .font(.subheadline)
                .foregroundStyle(
                    Color.white.opacity(0.48)
                )
        }
    }

    private var errorView: some View {
        VStack(spacing: 14) {
            Image(
                systemName: "exclamationmark.triangle.fill"
            )
            .font(.system(size: 28))
            .foregroundStyle(neonPink)

            Text("Could not load recap")
                .font(.headline)
                .foregroundStyle(.white)

            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(
                    Color.white.opacity(0.45)
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
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

    /// Floating pill making the second (Group) page discoverable -
    /// without this there's no visual hint that swiping left does
    /// anything. Doubles as a tap target so it's not swipe-only.
    private func pageIndicator(_ recap: RecapModel) -> some View {
        HStack(spacing: 6) {
            pageIndicatorLabel("Stats", page: 0)
            pageIndicatorLabel(
                recap.participants.count <= 1 ? "Solo" : "Group",
                page: 1
            )
        }
        .padding(4)
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.bottom, 14)
    }

    private func pageIndicatorLabel(
        _ label: String, page: Int
    ) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(
                selectedPage == page ? .white : .white.opacity(0.5)
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        selectedPage == page
                            ? neonPink
                            : Color.clear
                    )
            )
            .contentShape(Capsule())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedPage = page
                }
            }
    }

    private func heroSection(
        _ recap: RecapModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 10) {
                    if let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }

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

                Text("RECAP")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.3)
                    .foregroundStyle(
                        neonPink.opacity(0.9)
                    )
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(recap.title)
                    .font(
                        .system(
                            size: 38,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)

                Text(
                    formattedDate(
                        recap.started_at
                    )
                )
                .font(.subheadline)
                .foregroundStyle(
                    Color.white.opacity(0.48)
                )
            }

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
                width: 58,
                height: 3
            )
            .shadow(
                color: neonPink.opacity(0.65),
                radius: 8
            )
        }
    }

    private func durationCard(
        _ recap: RecapModel
    ) -> some View {
        VStack(spacing: 10) {
            Text("TOTAL NIGHT")
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.3)
                .foregroundStyle(
                    Color.white.opacity(0.38)
                )

            Text(
                formattedDuration(
                    start: recap.started_at,
                    end: recap.ended_at
                )
            )
            .font(
                .system(
                    size: 44,
                    weight: .bold,
                    design: .rounded
                )
            )
            .foregroundStyle(.white)

            Text("from first moment to last")
                .font(.caption)
                .foregroundStyle(
                    Color.white.opacity(0.35)
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            LinearGradient(
                colors: [
                    neonPink.opacity(0.10),
                    Color.white.opacity(0.045)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 24
            )
            .stroke(
                neonPink.opacity(0.12),
                lineWidth: 1
            )
        }
    }

    private func quickStatsSection(
        _ recap: RecapModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("THE NIGHT")

            HStack(spacing: 10) {
                statCard(
                    icon: "mappin.and.ellipse",
                    value: "\(recap.venue_stats.total_places ?? 0)",
                    label: "Places",
                    accent: neonPink
                )

                statCard(
                    icon: "figure.walk",
                    value: movementMinutesText(recap),
                    label: "Moving",
                    accent: softPink
                )

                statCard(
                    icon: "person.2.fill",
                    value: "\(recap.participants.count)",
                    label: "People",
                    accent: .purple
                )
            }
        }
    }

    private func funHighlightsSection(
        _ recap: RecapModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("AFTR SAYS")

                Spacer()

                Image(systemName: "sparkles")
                    .foregroundStyle(neonPink)
            }

            VStack(spacing: 12) {
                ForEach(recap.fun_highlights) { highlight in
                    funHighlightCard(highlight)
                }
            }
        }
    }

    private func funHighlightCard(
        _ highlight: FunHighlight
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            neonPink.opacity(0.14)
                        )
                        .frame(
                            width: 40,
                            height: 40
                        )

                    Image(
                        systemName: highlightIcon(
                            highlight.type
                        )
                    )
                    .foregroundStyle(neonPink)
                }

                Text(
                    highlight.title.uppercased()
                )
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(1.1)
                .foregroundStyle(neonPink)

                Spacer()
            }

            Text(highlight.text)
                .font(
                    .system(
                        size: 19,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    neonPink.opacity(0.11),
                    Color.white.opacity(0.045)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 20
            )
            .stroke(
                neonPink.opacity(0.13),
                lineWidth: 1
            )
        }
    }

    private func hasRoute(
        _ recap: RecapModel
    ) -> Bool {
        (recap.route ?? []).contains { participant in
            participant.points.count >= 2
        }
    }

    private func routeMapSection(
        _ recap: RecapModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("THE ROUTE")

            RouteReplayMap(
                routes: recap.route ?? [],
                venues: recap.venue_timeline
            )
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(neonPink.opacity(0.12), lineWidth: 1)
            }
        }
    }

    private func venueTimelineSection(
        _ recap: RecapModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("PLACES")

            VStack(spacing: 0) {
                ForEach(
                    Array(
                        recap.venue_timeline.enumerated()
                    ),
                    id: \.element.id
                ) { index, venue in
                    venueTimelineRow(
                        venue,
                        isLast:
                            index ==
                            recap.venue_timeline.count - 1
                    )
                }
            }
            .padding(18)
            .background(
                Color.white.opacity(0.05)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 20
                )
            )
        }
    }

    private func venueTimelineRow(
        _ venue: VenueTimelineItem,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(neonPink)
                        .frame(
                            width: 10,
                            height: 10
                        )

                    Circle()
                        .stroke(
                            neonPink.opacity(0.25),
                            lineWidth: 4
                        )
                        .frame(
                            width: 20,
                            height: 20
                        )
                }

                if !isLast {
                    Rectangle()
                        .fill(
                            Color.white.opacity(0.09)
                        )
                        .frame(
                            width: 1,
                            height: 54
                        )
                }
            }
            .frame(width: 20)

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(venue.venue_name)
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Text(
                        formattedTime(
                            venue.arrived_at
                        )
                    )

                    if let minutes =
                        venue.duration_minutes {
                        Text("•")

                        Text(
                            formatMinutes(minutes)
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(
                    Color.white.opacity(0.40)
                )

                if let category = venue.category {
                    Text(category.capitalized)
                        .font(.caption2)
                        .foregroundStyle(
                            neonPink.opacity(0.75)
                        )
                }
            }

            Spacer()
        }
    }

    private func movementSection(
        _ recap: RecapModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("MOVEMENT")

            HStack(spacing: 10) {
                movementCard(
                    icon: "figure.walk",
                    value:
                        recap.movement_stats.walking_minutes,
                    label: "Walking"
                )

                movementCard(
                    icon: "figure.run",
                    value:
                        recap.movement_stats.fast_movement_minutes,
                    label: "Fast"
                )
            }

            HStack(spacing: 10) {
                movementCard(
                    icon: "car.fill",
                    value:
                        recap.movement_stats.vehicle_minutes,
                    label: "Vehicle"
                )

                movementCard(
                    icon: "pause.fill",
                    value:
                        recap.movement_stats.stationary_minutes,
                    label: "Still"
                )
            }
        }
    }

    private func movementCard(
        icon: String,
        value: Double,
        label: LocalizedStringKey
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 12
                )
                .fill(
                    neonPink.opacity(0.10)
                )
                .frame(
                    width: 42,
                    height: 42
                )

                Image(systemName: icon)
                    .foregroundStyle(neonPink)
            }

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(formatMinutes(value))
                    .font(
                        .system(
                            size: 17,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(
                        Color.white.opacity(0.38)
                    )
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            Color.white.opacity(0.05)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 17
            )
        )
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(neonPink)
                    .frame(
                        width: 5,
                        height: 5
                    )

                Circle()
                    .fill(softPink)
                    .frame(
                        width: 5,
                        height: 5
                    )

                Circle()
                    .fill(Color.purple)
                    .frame(
                        width: 5,
                        height: 5
                    )
            }

            Text("REMEMBER TOMORROW")
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.3)
                .foregroundStyle(
                    Color.white.opacity(0.25)
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
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

    private func statCard(
        icon: String,
        value: String,
        label: LocalizedStringKey,
        accent: Color
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(accent)

            Text(value)
                .font(
                    .system(
                        size: 18,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)

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

    private func highlightIcon(
        _ type: String
    ) -> String {
        switch type {
        case "most_distance":
            return "figure.walk"

        case "most_independent":
            return "person.fill.questionmark"

        case "dynamic_duo":
            return "person.2.fill"

        case "group_splits":
            return "arrow.triangle.branch"

        default:
            return "sparkles"
        }
    }

    private func movementMinutesText(
        _ recap: RecapModel
    ) -> String {
        let total =
            recap.movement_stats.walking_minutes +
            recap.movement_stats.fast_movement_minutes +
            recap.movement_stats.vehicle_minutes

        return formatMinutes(total)
    }

    private func formatMinutes(
        _ minutes: Double
    ) -> String {
        if minutes < 1 {
            return "<1m"
        }

        if minutes < 60 {
            return "\(Int(round(minutes)))m"
        }

        let totalMinutes =
            Int(round(minutes))

        let hours =
            totalMinutes / 60

        let remainingMinutes =
            totalMinutes % 60

        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }

    private func formattedDate(
        _ string: String
    ) -> String {
        guard let date =
            parseISODate(string)
        else {
            return string
        }

        return date.formatted(
            .dateTime
                .weekday(.wide)
                .day()
                .month(.wide)
        )
    }

    private func formattedTime(
        _ string: String
    ) -> String {
        guard let date =
            parseISODate(string)
        else {
            return ""
        }

        return date.formatted(
            date: .omitted,
            time: .shortened
        )
    }

    private func formattedDuration(
        start: String,
        end: String?
    ) -> String {
        guard
            let startDate =
                parseISODate(start),
            let end,
            let endDate =
                parseISODate(end)
        else {
            return "—"
        }

        let seconds =
            max(
                0,
                Int(
                    endDate.timeIntervalSince(
                        startDate
                    )
                )
            )

        let hours =
            seconds / 3600

        let minutes =
            (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    private func parseISODate(
        _ string: String
    ) -> Date? {
        ISO8601DateFormatter.aftrDate(from: string)
    }

    @MainActor
    private func loadRecap() async {
        isLoading = true
        errorMessage = ""

        do {
            recap =
                try await apiService.getRecap(
                    nightId: nightId
                )
        } catch {
            errorMessage =
                error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    private func loadMedia() async {
        media = (
            try? await apiService.getMedia(nightId: nightId)
        ) ?? media
    }

    private func bestMomentsSection(
        _ recap: RecapModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("BEST MOMENTS")

                Spacer()

                Button {
                    showAddPhotos = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                        if media.isEmpty {
                            Text("Add photos")
                        } else {
                            Text("Add")
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(neonPink)
                }
            }

            if media.isEmpty {
                Text(
                    "Pull in the photos you took during this Night."
                )
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.4))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(
                            Array(media.enumerated()),
                            id: \.element.id
                        ) { index, item in
                            momentCell(item)
                                .onTapGesture {
                                    viewerStart = ViewerStart(id: index)
                                }
                        }
                    }
                }
            }
        }
    }

    private func momentCell(
        _ item: NightMedia
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: item.imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.white.opacity(0.06)
            }
            .frame(width: 150, height: 190)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if let venue = item.venue_name {
                Text(venue)
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(1)
            } else if let taken = item.taken_at,
                      let date = parseISODate(taken) {
                Text(
                    date.formatted(date: .omitted, time: .shortened)
                )
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.55))
            }
        }
        .frame(width: 150)
    }
}

#Preview {
    RecapView(
        nightId: "test-night-id"
    )
}

import SwiftUI

struct MonthlyWrapView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var wrap: MonthlyWrap?
    @State private var isLoading = true
    @State private var failed = false

    private let apiService = APIService()

    private let neonPink = Color(red: 1.0, green: 0.10, blue: 0.58)
    private let softPink = Color(red: 1.0, green: 0.32, blue: 0.72)

    var body: some View {
        ZStack {
            background

            if isLoading {
                ProgressView().tint(neonPink)
            } else if let wrap, wrap.nights > 0 {
                content(wrap)
            } else {
                emptyState
            }

            closeButton
        }
        .task {
            wrap = try? await apiService.getWrap()
            failed = wrap == nil
            isLoading = false
        }
    }

    private func content(_ wrap: MonthlyWrap) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(monthName(wrap.month).uppercased())
                        .font(.caption).fontWeight(.semibold).tracking(2)
                        .foregroundStyle(neonPink)
                    Text("Your month out")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.top, 40)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    bigStat("\(wrap.nights)", "Nights out", "moon.stars.fill")
                    bigStat(hours(wrap.hours_out), "Out and about", "clock.fill")
                    bigStat(
                        String(format: "%.1f km", wrap.distance_km),
                        "You covered", "figure.walk"
                    )
                    bigStat(
                        "\(wrap.unique_venues)",
                        wrap.venues_visited == wrap.unique_venues
                            ? "Places"
                            : "Places · \(wrap.venues_visited) stops",
                        "mappin.and.ellipse"
                    )
                }

                if let index = wrap.busiest_weekday_index {
                    lineStat("Your night", weekdayName(index), "calendar")
                }
                if let hour = wrap.latest_end_hour {
                    lineStat("Latest you called it", clock(hour), "sunrise.fill")
                }

                if !wrap.top_people.isEmpty {
                    listSection("YOUR CREW", wrap.top_people, unit: "nights")
                }
                if !wrap.top_venues.isEmpty {
                    listSection("YOUR SPOTS", wrap.top_venues, unit: "visits")
                }

                Text("REMEMBER TOMORROW")
                    .font(.caption2).fontWeight(.semibold).tracking(1.4)
                    .foregroundStyle(Color.white.opacity(0.25))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8).padding(.bottom, 40)
            }
            .padding(.horizontal, 22)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 30))
                .foregroundStyle(neonPink.opacity(0.7))
            Text("No nights yet this month")
                .font(.headline).foregroundStyle(.white)
            Text("Start one and it'll show up here.")
                .font(.caption).foregroundStyle(Color.white.opacity(0.45))
        }
    }

    private func bigStat(
        _ value: String, _ label: LocalizedStringKey, _ icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(neonPink)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(label)
                .font(.caption2).foregroundStyle(Color.white.opacity(0.4))
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func lineStat(
        _ label: LocalizedStringKey, _ value: String, _ icon: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(neonPink)
            Text(label).font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.55))
            Spacer()
            Text(value).font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(15)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func listSection(
        _ title: LocalizedStringKey, _ rows: [WrapCount], unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption2).fontWeight(.semibold).tracking(1.3)
                .foregroundStyle(Color.white.opacity(0.42))
            VStack(spacing: 8) {
                ForEach(rows) { row in
                    HStack {
                        Text(row.name).foregroundStyle(.white)
                        Spacer()
                        Text("\(row.count) \(unit)")
                            .font(.caption)
                            .foregroundStyle(neonPink.opacity(0.85))
                    }
                    .font(.subheadline)
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [neonPink.opacity(0.18), Color.purple.opacity(0.08), .clear],
                center: .topTrailing, startRadius: 20, endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    // MARK: helpers

    private func hours(_ h: Double) -> String {
        if h < 1 { return "<1h" }
        let whole = Int(h)
        let mins = Int((h - Double(whole)) * 60)
        return mins == 0 ? "\(whole)h" : "\(whole)h \(mins)m"
    }

    private func clock(_ hour: Double) -> String {
        var h = Int(hour) % 24
        let m = Int((hour - Double(Int(hour))) * 60)
        if h < 0 { h += 24 }
        return String(format: "%02d:%02d", h, m)
    }

    /// index: Monday = 0 ... Sunday = 6 (as sent by the backend).
    /// `weekdaySymbols` is always Sunday-first regardless of locale, so
    /// we shift into that frame before indexing.
    private func weekdayName(_ index: Int) -> String {
        let sundayFirst = (index + 1) % 7
        let symbols = Calendar.current.weekdaySymbols
        guard symbols.indices.contains(sundayFirst) else { return "" }
        return symbols[sundayFirst]
    }

    private func monthName(_ ym: String) -> String {
        let parts = ym.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[1]), (1...12).contains(m) else {
            return ym
        }
        var comps = DateComponents()
        comps.month = m
        comps.year = Int(parts[0])
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(.dateTime.month(.wide).year())
    }
}

#Preview {
    MonthlyWrapView()
}

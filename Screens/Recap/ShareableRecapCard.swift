import SwiftUI

/// A 9:16 (Instagram Story shaped) summary of a Night, rendered to an
/// image via ImageRenderer and shared through the system share sheet.
/// This is the single biggest lever for AFTR to actually spread - a
/// recap that's fun to post gets far more reach than word of mouth.
struct ShareableRecapCard: View {
    let recap: RecapModel

    private var isChillVibe: Bool { recap.vibe == "chill" }

    private var neonPink: Color {
        isChillVibe
            ? Color(red: 0.35, green: 0.55, blue: 1.0)
            : Color(red: 1.0, green: 0.10, blue: 0.58)
    }

    private var softPink: Color {
        isChillVibe
            ? Color(red: 0.55, green: 0.70, blue: 1.0)
            : Color(red: 1.0, green: 0.32, blue: 0.72)
    }

    /// Fixed render size rather than letting the view size itself -
    /// ImageRenderer needs a concrete frame, and this matches Instagram/
    /// Snapchat Story dimensions exactly so it drops in with no cropping.
    static let renderSize = CGSize(width: 1080, height: 1920)

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 90)

                Spacer(minLength: 40)

                Text(recap.title)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(dateText)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 10)

                statsRow
                    .padding(.top, 50)

                if let highlight = recap.fun_highlights.first {
                    highlightCard(highlight)
                        .padding(.top, 50)
                }

                Spacer()

                footer
                    .padding(.bottom, 90)
            }
            .padding(.horizontal, 72)
        }
        .frame(
            width: Self.renderSize.width,
            height: Self.renderSize.height
        )
    }

    private var background: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [neonPink.opacity(0.30), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 900
            )

            RadialGradient(
                colors: [Color.purple.opacity(0.16), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 800
            )
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            aftrMark(size: 56)

            Text("AFTR")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 20) {
            statTile(
                value: durationText,
                label: "DURATION"
            )
            statTile(
                value: "\(recap.venue_stats.total_places ?? 0)",
                label: "PLACES"
            )
            statTile(
                value: "\(recap.participants.count)",
                label: recap.participants.count == 1 ? "PERSON" : "PEOPLE"
            )
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func highlightCard(_ highlight: FunHighlight) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(highlight.title.uppercased())
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(neonPink)

            Text(highlight.text)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(neonPink.opacity(0.35), lineWidth: 1.5)
                )
        )
    }

    private var footer: some View {
        Text("Live tonight. Remember tomorrow.")
            .font(.system(size: 22, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.4))
    }

    private func aftrMark(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.09)
                .fill(
                    LinearGradient(
                        colors: [softPink, neonPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.19, height: size * 0.72)
                .rotationEffect(.degrees(32))
                .offset(x: -size * 0.19)

            RoundedRectangle(cornerRadius: size * 0.09)
                .fill(
                    LinearGradient(
                        colors: [softPink, neonPink],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .frame(width: size * 0.19, height: size * 0.72)
                .rotationEffect(.degrees(-32))
                .offset(x: size * 0.19)
        }
        .frame(width: size, height: size * 0.82)
        .shadow(color: neonPink.opacity(0.6), radius: size * 0.22)
    }

    private var dateText: String {
        guard let date = ISO8601DateFormatter.aftrDate(from: recap.started_at)
        else { return "" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private var durationText: String {
        guard
            let start = ISO8601DateFormatter.aftrDate(from: recap.started_at),
            let endedAt = recap.ended_at,
            let end = ISO8601DateFormatter.aftrDate(from: endedAt)
        else { return "—" }

        let minutes = max(0, Int(end.timeIntervalSince(start) / 60))
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

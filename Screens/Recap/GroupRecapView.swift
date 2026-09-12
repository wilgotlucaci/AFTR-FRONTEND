import SwiftUI

/// The second page of a recap (swipe left from RecapView) - always
/// present regardless of participant count. Solo Nights get one teasing
/// one-liner instead of stats; group Nights get the group-only
/// highlights (houdini moments, reunions, dynamic duo, etc. - see
/// utils/fun_recap.py's build_group_facts on the backend) plus the
/// places everyone visited together.
struct GroupRecapView: View {
    let recap: RecapModel

    private let neonPink = Color(red: 1.0, green: 0.10, blue: 0.58)
    private let softPink = Color(red: 1.0, green: 0.32, blue: 0.72)

    private var isSolo: Bool { recap.participants.count <= 1 }
    private var groupHighlights: [FunHighlight] { recap.group_highlights ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                if isSolo {
                    soloCard
                } else {
                    if !groupHighlights.isEmpty {
                        highlightsSection
                    }

                    if !recap.venue_timeline.isEmpty {
                        placesTogetherSection
                    }

                    if groupHighlights.isEmpty && recap.venue_timeline.isEmpty {
                        emptyGroupState
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 50)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GROUP RECAP")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(neonPink)

            Text(isSolo ? "Flying Solo" : "Together Tonight")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var soloCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(neonPink.opacity(0.16))
                        .frame(width: 40, height: 40)

                    Image(systemName: "person.fill.questionmark")
                        .foregroundStyle(neonPink)
                }

                Text("SOLO NIGHT")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(neonPink)

                Spacer()
            }

            Text(
                groupHighlights.first?.text
                    ?? "No one joined your night. Get some friends."
            )
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var highlightsSection: some View {
        VStack(spacing: 12) {
            ForEach(groupHighlights) { highlight in
                highlightCard(highlight)
            }
        }
    }

    private func highlightCard(_ highlight: FunHighlight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(highlight.title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(neonPink)

            Text(highlight.text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
        )
    }

    private var placesTogetherSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PLACES YOU VISITED TOGETHER")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.5))

            VStack(spacing: 8) {
                ForEach(recap.venue_timeline) { item in
                    HStack {
                        Text(item.venue_name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)

                        Spacer()

                        if let duration = item.duration_minutes {
                            Text(formatMinutes(duration))
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.03))
                    )
                }
            }
        }
    }

    private var emptyGroupState: some View {
        Text("Nothing to report from the group tonight.")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.6))
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let total = Int(minutes)
        guard total >= 60 else { return "\(total)m" }
        return "\(total / 60)h \(total % 60)m"
    }
}

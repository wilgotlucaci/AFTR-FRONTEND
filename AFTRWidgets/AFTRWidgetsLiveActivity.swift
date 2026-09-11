//
//  AFTRWidgetsLiveActivity.swift
//  AFTRWidgets
//
//  Created by Wilgot Lucaci on 2026-09-11.
//

import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

private let neonPink = Color(red: 1.0, green: 0.10, blue: 0.58)
private let softPink = Color(red: 1.0, green: 0.32, blue: 0.72)

struct AFTRWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NightActivityAttributes.self) { context in
            lockScreen(context: context)
                // A near-black tint (not fully opaque) lets the Lock
                // Screen wallpaper show through at the edges, the way
                // the system's own Live Activities blend in, rather
                // than sitting on top as a flat black card.
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        aftrMark(size: 16)
                        Text(context.state.nightTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.65))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    endNightButton(context: context)
                        .padding(.top, 4)
                }
            } compactLeading: {
                aftrMark(size: 15)
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(neonPink)
                    .frame(width: 44)
            } minimal: {
                aftrMark(size: 15)
            }
            .keylineTint(neonPink)
        }
    }

    // MARK: - Lock Screen

    private func lockScreen(
        context: ActivityViewContext<NightActivityAttributes>
    ) -> some View {
        ZStack {
            cardBackground

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(neonPink.opacity(0.16))
                            .frame(width: 38, height: 38)
                        aftrMark(size: 18)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("NIGHT ACTIVE")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(neonPink)

                        Text(context.state.nightTitle)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(context.state.startedAt, style: .timer)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.85))
                }

                endNightButton(context: context)
            }
            .padding(16)
        }
    }

    private var cardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.12, green: 0.02, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [neonPink.opacity(0.30), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 160
            )

            RadialGradient(
                colors: [Color.purple.opacity(0.18), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 140
            )
        }
    }

    // MARK: - Shared bits

    /// The AFTR wordmark's icon - two crossed, angled bars forming a
    /// glowing chevron. Matches the mark used throughout the app itself.
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

    private func endNightButton(
        context: ActivityViewContext<NightActivityAttributes>
    ) -> some View {
        Button(intent: EndNightIntent(nightId: context.attributes.nightId)) {
            HStack(spacing: 7) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("End Night")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                LinearGradient(
                    colors: [Color.white, softPink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

extension NightActivityAttributes {
    fileprivate static var preview: NightActivityAttributes {
        NightActivityAttributes(nightId: "preview")
    }
}

extension NightActivityAttributes.ContentState {
    fileprivate static var running: NightActivityAttributes.ContentState {
        NightActivityAttributes.ContentState(
            nightTitle: "Friday Night",
            startedAt: .now.addingTimeInterval(-1800)
        )
    }
}

#Preview("Notification", as: .content, using: NightActivityAttributes.preview) {
    AFTRWidgetsLiveActivity()
} contentStates: {
    NightActivityAttributes.ContentState.running
}

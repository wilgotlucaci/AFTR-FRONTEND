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

struct AFTRWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NightActivityAttributes.self) { context in
            lockScreen(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.nightTitle)
                            .font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(neonPink)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    endNightButton(context: context)
                }
            } compactLeading: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(neonPink)
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(neonPink)
            }
            .keylineTint(neonPink)
        }
    }

    private func lockScreen(
        context: ActivityViewContext<NightActivityAttributes>
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "moon.stars.fill")
                    .font(.headline)
                    .foregroundStyle(neonPink)

                VStack(alignment: .leading, spacing: 2) {
                    Text("NIGHT ACTIVE")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(neonPink)

                    Text(context.state.nightTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Spacer()

                Text(context.state.startedAt, style: .timer)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
            }

            endNightButton(context: context)
        }
        .padding(16)
    }

    private func endNightButton(
        context: ActivityViewContext<NightActivityAttributes>
    ) -> some View {
        Button(intent: EndNightIntent(nightId: context.attributes.nightId)) {
            HStack {
                Image(systemName: "stop.fill")
                Text("End Night")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .tint(neonPink)
        .buttonStyle(.borderedProminent)
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

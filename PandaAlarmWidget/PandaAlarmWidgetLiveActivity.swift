//
//  PandaAlarmWidgetLiveActivity.swift
//  PandaAlarmWidget
//
//  Created by Gavin John on 7/29/26.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AlarmKit

struct PandaAlarmWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<AlarmInstanceMetadata>.self) { context in
            lockScreenView(context: context)
                .padding()
                .activityBackgroundTint(.secondary.opacity(0.15))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    alarmIcon(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    // TODO: Replace placeholder
                    Text(context.attributes.metadata?.title ?? "PLACEHOLDER")
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(context: context)
                }
            } compactLeading: {
                alarmIcon(context: context)
                    .imageScale(.small)
            } compactTrailing: {
                timerText(context: context)
            } minimal: {
                alarmIcon(context: context)
                    .imageScale(.small)
            }
        }
    }
}

private extension PandaAlarmWidgetLiveActivity {
    func alarmIcon(context: ActivityViewContext<AlarmAttributes<AlarmInstanceMetadata>>) -> some View {
        return Image(systemName: "alarm")
            .foregroundStyle(.primary)
    }
    
    @ViewBuilder
    func timerText(context: ActivityViewContext<AlarmAttributes<AlarmInstanceMetadata>>) -> some View {
        switch context.state.mode {
        case .alert:
            EmptyView()
        case .countdown(let info):
            Text(info.fireDate, style: .timer)
                .monospacedDigit()
                .font(.caption)
        case .paused:
            EmptyView()
        @unknown default:
            /// TODO: Should handle this better
            EmptyView()
        }
    }
    
    @ViewBuilder
    func lockScreenView(context: ActivityViewContext<AlarmAttributes<AlarmInstanceMetadata>>) -> some View {
        switch context.state.mode {
        case .alert:
            alertLockScreen(context: context)
        case .countdown:
            countdownLockScreen(context: context)
        case .paused:
            EmptyView()
        @unknown default:
            /// TODO: Should handle this better
            EmptyView()
        }
    }
    
    func countdownLockScreen(context: ActivityViewContext<AlarmAttributes<AlarmInstanceMetadata>>) -> some View {
        guard case .countdown(let info) = context.state.mode else { return AnyView(EmptyView()) }
        return AnyView(
            HStack {
                alarmIcon(context: context)
                    .font(.callout)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.metadata?.title ?? "Alarm")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Snoozed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(info.fireDate, style: .timer)
                    .monospacedDigit()
                    .font(.title)
                    .fontWeight(.semibold)
            }
        )
    }
    
    func alertLockScreen(context: ActivityViewContext<AlarmAttributes<AlarmInstanceMetadata>>) -> some View {
        HStack {
            alarmIcon(context: context)
                .font(.callout)
            VStack {
                // TODO: Replace placeholder
                Text(context.attributes.metadata?.title ?? "PLACEHOLDER")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "alarm.waves.left.and.right")
            }
        }
    }
}



//#Preview("Notification", as: .content, using: PandaAlarmWidgetAttributes.preview) {
//   PandaAlarmWidgetLiveActivity()
//} contentStates: {
//    PandaAlarmWidgetAttributes.ContentState.smiley
//    PandaAlarmWidgetAttributes.ContentState.starEyes
//}

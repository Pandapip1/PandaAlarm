//
//  PandaAlarmWidgetLiveActivity.swift
//  PandaAlarmWidget
//
//  Created by Gavin John on 7/29/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PandaAlarmWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct PandaAlarmWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PandaAlarmWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension PandaAlarmWidgetAttributes {
    fileprivate static var preview: PandaAlarmWidgetAttributes {
        PandaAlarmWidgetAttributes(name: "World")
    }
}

extension PandaAlarmWidgetAttributes.ContentState {
    fileprivate static var smiley: PandaAlarmWidgetAttributes.ContentState {
        PandaAlarmWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PandaAlarmWidgetAttributes.ContentState {
         PandaAlarmWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: PandaAlarmWidgetAttributes.preview) {
   PandaAlarmWidgetLiveActivity()
} contentStates: {
    PandaAlarmWidgetAttributes.ContentState.smiley
    PandaAlarmWidgetAttributes.ContentState.starEyes
}

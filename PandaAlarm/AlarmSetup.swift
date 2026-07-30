//
//  AlarmSetup.swift
//  PandaAlarm
//
//  Created by Gavin John on 7/29/26.
//

import AlarmKit
import SwiftUI
import ActivityKit
import AppIntents

/// https://forums.swift.org/t/migrating-to-swift-duration/63347
extension Duration {
    /// Possibly lossy conversion to TimeInterval
    var timeInterval: TimeInterval {
        TimeInterval(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}

func makeConfiguration(id: UUID, meta: AlarmInstanceMetadata, schedule: Alarm.Schedule?, stopIntent: (any LiveActivityIntent)? = nil, preAlert: TimeInterval? = nil) -> AlarmManager.AlarmConfiguration<AlarmInstanceMetadata> {
    return AlarmManager.AlarmConfiguration(
        countdownDuration: Alarm.CountdownDuration(
            preAlert: preAlert,
            postAlert: meta.snoozeDuration.timeInterval
        ),
        schedule: schedule,
        attributes: AlarmAttributes<AlarmInstanceMetadata>(
            presentation: makePresentation(meta: meta),
            metadata: meta,
            tintColor: .accentColor
        ),
        stopIntent: stopIntent,
        sound: .default
    )
}

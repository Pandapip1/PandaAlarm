//
//  AlarmSetup.swift
//  PandaAlarm
//
//  Created by Gavin John on 7/29/26.
//

import AlarmKit
import SwiftUI
import AppIntents
import ActivityKit

/// https://forums.swift.org/t/migrating-to-swift-duration/63347
extension Duration {
    /// Possibly lossy conversion to TimeInterval
    var timeInterval: TimeInterval {
        TimeInterval(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}

struct AlarmSnoozeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Snooze"
    @Parameter(title: "Alarm") var alarm: AlarmEntity
    init() { }
    init(alarm: AlarmEntity) { self.alarm = alarm }
    func perform() async throws -> some IntentResult {
        try AlarmManager.shared.stop(id: self.alarm.id)
        return .result()
    }
}

struct AlarmDismissIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Dismiss"
    @Parameter(title: "Alarm") var alarm: AlarmEntity
    init() { }
    init(alarm: AlarmEntity) { self.alarm = alarm }
    func perform() async throws -> some IntentResult {
        try AlarmManager.shared.stop(id: self.alarm.id)
        return .result()
    }
}

func makeConfiguration(id: UUID, meta: AlarmInstanceMetadata, schedule: Alarm.Schedule?) -> AlarmManager.AlarmConfiguration<AlarmInstanceMetadata> {
    return AlarmManager.AlarmConfiguration(
        countdownDuration: Alarm.CountdownDuration(
            preAlert: nil,
            postAlert: meta.snoozeDuration.timeInterval
        ),
        schedule: schedule,
        attributes: AlarmAttributes<AlarmInstanceMetadata>(
            presentation: makePresentation(meta: meta),
            metadata: meta,
            tintColor: .accentColor
        ),
        stopIntent: AlarmDismissIntent(alarm: AlarmEntity(id: id)),
        secondaryIntent: AlarmSnoozeIntent(alarm: AlarmEntity(id: id)),
        sound: .default
    )
}

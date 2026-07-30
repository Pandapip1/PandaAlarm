import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI

struct AlarmDismissIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Snooze"

    @Parameter(title: "Snooze Duration Seconds") var snoozeDurationSeconds: Double
    @Parameter(title: "Alarm Title") var alarmTitle: String

    init() {}
    init(snoozeDurationSeconds: Double, alarmTitle: String) {
        self.snoozeDurationSeconds = snoozeDurationSeconds
        self.alarmTitle = alarmTitle
    }

    @MainActor func perform() async throws -> some IntentResult {
        let newID = UUID()
        let metadata = AlarmInstanceMetadata(
            enabled: true,
            title: alarmTitle,
            scheduledTime: DateComponents(),
            snoozeDuration: Duration.seconds(snoozeDurationSeconds),
            task: .none
        )
        let nextIntent = AlarmDismissIntent(
            snoozeDurationSeconds: snoozeDurationSeconds,
            alarmTitle: alarmTitle
        )
        let configuration = AlarmManager.AlarmConfiguration<AlarmInstanceMetadata>.timer(
            duration: snoozeDurationSeconds,
            attributes: AlarmAttributes<AlarmInstanceMetadata>(
                presentation: makePresentation(meta: metadata),
                metadata: metadata,
                tintColor: .accentColor
            ),
            stopIntent: nextIntent,
            sound: .default
        )

        var knownIDs = UserDefaults.standard.stringArray(forKey: "com.pandapip1.PandaAlarm.snoozeAlarmIDs") ?? []
        knownIDs.append(newID.uuidString)
        UserDefaults.standard.set(knownIDs, forKey: "com.pandapip1.PandaAlarm.snoozeAlarmIDs")

        _ = try await AlarmManager.shared.schedule(id: newID, configuration: configuration)
        return .result()
    }
}

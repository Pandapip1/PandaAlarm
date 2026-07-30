//
//  AlarmKitSynchronizer.swift
//  PandaAlarm
//
//  Created by Gavin John on 7/30/26.
//

import AlarmKit
import SwiftUI

@MainActor
final class AlarmKitSynchronizer {
    private actor SerialQueue {
        private var tail: Task<Void, Never>?

        func enqueue(_ operation: @escaping @MainActor () async -> Void) async {
            let previous = tail
            let task = Task { @MainActor in
                _ = await previous?.value
                await operation()
            }
            tail = task
            await task.value
        }
    }

    private let queue = SerialQueue()

    private var locallyKnownScheduledIds: Set<UUID> = []

    private var lastPushedMetadata: [UUID: AlarmInstanceMetadata] = [:]

    func requestReconcile(against localAlarms: IdentifiedSet<AlarmInstanceMetadata>) async {
        await queue.enqueue { [self] in
            do {
                let systemAlarms = try AlarmManager.shared.alarms
                let systemAlarmIds = Set(systemAlarms.map { $0.id }).union(locallyKnownScheduledIds)
                await reconcile(localAlarms: localAlarms, against: systemAlarmIds)
            } catch {
                print("Failed to fetch system alarms: \(error)")
            }
        }
    }

    private func reconcile(localAlarms: IdentifiedSet<AlarmInstanceMetadata>, against systemAlarmIds: Set<UUID>) async {
        let locallyEnabledIds = Set(localAlarms.ids.filter { localAlarms[$0]?.enabled ?? false })
        let alarmIdsToAdd = locallyEnabledIds.subtracting(systemAlarmIds)
        let alarmIdsToUpdate = locallyEnabledIds.intersection(systemAlarmIds).filter { id in
            guard let metadata = localAlarms[id] else { return false }
            return lastPushedMetadata[id] != metadata
        }
        let alarmIdsToRemove = systemAlarmIds.subtracting(locallyEnabledIds)

        for id in alarmIdsToAdd.union(alarmIdsToUpdate) {
            guard let metadata = localAlarms[id] else { continue }
            await scheduleSystemAlarm(id: id, metadata: metadata)
        }

        for id in alarmIdsToRemove {
            await cancelSystemAlarm(id: id)
        }
    }

    private func scheduleSystemAlarm(id: UUID, metadata: AlarmInstanceMetadata) async {
        guard let hour = metadata.scheduledTime.hour, let minute = metadata.scheduledTime.minute else {
            assertionFailure("AlarmInstanceMetadata.scheduledTime must at least specify hour and minute")
            return
        }

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: metadata.title)
        )
        let presentation = AlarmPresentation(alert: alert)
        let attributes = AlarmAttributes<AlarmInstanceMetadata>(
            presentation: presentation,
            metadata: metadata,
            tintColor: .accentColor,
        )

        let schedule = Alarm.Schedule.relative(
            .init(time: .init(hour: hour, minute: minute), repeats: .never)
        )
        let configuration = AlarmManager.AlarmConfiguration<AlarmInstanceMetadata>.alarm(
            schedule: schedule,
            attributes: attributes
        )

        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            locallyKnownScheduledIds.insert(id)
            lastPushedMetadata[id] = metadata
        } catch {
            if "\(error)".contains("duplicate ID") {
                locallyKnownScheduledIds.insert(id)
                lastPushedMetadata[id] = metadata
            } else {
                print("Failed to schedule alarm \(id): \(error)")
            }
        }
    }

    private func cancelSystemAlarm(id: UUID) async {
        do {
            try AlarmManager.shared.cancel(id: id)
            locallyKnownScheduledIds.remove(id)
            lastPushedMetadata.removeValue(forKey: id)
        } catch {
            if "\(error)".contains("unknownAlarm") {
                locallyKnownScheduledIds.remove(id)
                lastPushedMetadata.removeValue(forKey: id)
            } else {
                print("Failed to cancel alarm \(id): \(error)")
            }
        }
    }
}

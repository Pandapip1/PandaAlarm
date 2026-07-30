//
//  AlarmKitSynchronizer.swift
//  PandaAlarm
//
//  Created by Gavin John on 7/30/26.
//

import AlarmKit
import SwiftUI

private let snoozeAlarmMappingKey = "com.pandapip1.PandaAlarm.snoozeAlarmMapping"

// Number of snooze rounds pre-scheduled alongside each main alarm.
private let snoozeRoundCount = 2

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

    // Alarms scheduled outside the normal set (e.g. demo timers) that the reconciler must not cancel.
    private var ephemeralAlarmIDs: Set<UUID> = []

    // MARK: - Public

    func registerExternalAlarm(id: UUID) {
        ephemeralAlarmIDs.insert(id)
    }

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

    // MARK: - Snooze mapping

    private func snoozeMapping() -> [String: [String]] {
        (UserDefaults.standard.dictionary(forKey: snoozeAlarmMappingKey) as? [String: [String]]) ?? [:]
    }

    private func saveSnoozeMapping(_ mapping: [String: [String]]) {
        UserDefaults.standard.set(mapping, forKey: snoozeAlarmMappingKey)
    }

    private func allSnoozeIDs(in mapping: [String: [String]]) -> Set<UUID> {
        Set(mapping.values.flatMap { $0 }.compactMap(UUID.init))
    }

    // MARK: - Reconcile

    private func reconcile(localAlarms: IdentifiedSet<AlarmInstanceMetadata>, against systemAlarmIds: Set<UUID>) async {
        let locallyEnabledIds = Set(localAlarms.ids.filter { localAlarms[$0]?.enabled ?? false })
        let alarmIdsToAdd = locallyEnabledIds.subtracting(systemAlarmIds)
        let alarmIdsToUpdate = locallyEnabledIds.intersection(systemAlarmIds).filter { id in
            guard let metadata = localAlarms[id] else { return false }
            return lastPushedMetadata[id] != metadata
        }

        // Remove stale snooze IDs from mapping (fired alarms are removed from AlarmKit).
        var mapping = snoozeMapping()
        for (mainIDStr, snoozeIDStrs) in mapping {
            let active = snoozeIDStrs.filter { s in UUID(uuidString: s).map { systemAlarmIds.contains($0) } ?? false }
            if active.isEmpty {
                mapping.removeValue(forKey: mainIDStr)
            } else if active.count != snoozeIDStrs.count {
                mapping[mainIDStr] = active
            }
        }
        saveSnoozeMapping(mapping)

        let snoozeIDs = allSnoozeIDs(in: mapping)

        // Drop ephemeral IDs that have already fired and left the system.
        ephemeralAlarmIDs = ephemeralAlarmIDs.intersection(systemAlarmIds)

        let alarmIdsToRemove = systemAlarmIds
            .subtracting(locallyEnabledIds)
            .subtracting(snoozeIDs)
            .subtracting(ephemeralAlarmIDs)

        for id in alarmIdsToAdd.union(alarmIdsToUpdate) {
            guard let metadata = localAlarms[id] else { continue }
            await scheduleSystemAlarm(id: id, metadata: metadata)
        }

        for id in alarmIdsToRemove {
            await cancelSystemAlarm(id: id)
        }
    }

    // MARK: - Schedule

    private func scheduleSystemAlarm(id: UUID, metadata: AlarmInstanceMetadata) async {
        guard let hour = metadata.scheduledTime.hour, let minute = metadata.scheduledTime.minute else {
            assertionFailure("AlarmInstanceMetadata.scheduledTime must at least specify hour and minute")
            return
        }

        let schedule = Alarm.Schedule.relative(.init(time: .init(hour: hour, minute: minute), repeats: .never))
        let configuration = makeConfiguration(id: id, meta: metadata, schedule: schedule)

        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            locallyKnownScheduledIds.insert(id)
            lastPushedMetadata[id] = metadata
            await refreshSnoozeAlarms(for: id, hour: hour, minute: minute, metadata: metadata)
        } catch {
            if "\(error)".contains("duplicate ID") {
                locallyKnownScheduledIds.insert(id)
                lastPushedMetadata[id] = metadata
                // Only schedule snooze alarms if none exist yet for this main alarm.
                let mapping = snoozeMapping()
                if mapping[id.uuidString] == nil {
                    await refreshSnoozeAlarms(for: id, hour: hour, minute: minute, metadata: metadata)
                }
            } else {
                print("Failed to schedule alarm \(id): \(error)")
            }
        }
    }

    // Cancels any existing snooze alarms for `mainID` and schedules fresh ones.
    private func refreshSnoozeAlarms(for mainID: UUID, hour: Int, minute: Int, metadata: AlarmInstanceMetadata) async {
        // Cancel stale snooze alarms if metadata changed.
        cancelSnoozeAlarms(for: mainID)

        guard let mainDate = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: hour, minute: minute),
            matchingPolicy: .nextTime
        ) else { return }

        let snoozeDuration = metadata.snoozeDuration.timeInterval
        var scheduledIDs: [String] = []

        for round in 1...snoozeRoundCount {
            let snoozeFireDate = mainDate.addingTimeInterval(Double(round) * snoozeDuration)
            let snoozeComps = Calendar.current.dateComponents([.hour, .minute], from: snoozeFireDate)
            guard let sh = snoozeComps.hour, let sm = snoozeComps.minute else { continue }

            let snoozeID = UUID()
            let snoozeSchedule = Alarm.Schedule.relative(.init(time: .init(hour: sh, minute: sm), repeats: .never))
            // preAlert = snoozeDuration so the countdown Live Activity begins exactly when the
            // previous alarm fires (main alarm or prior snooze round).
            let snoozeConfig = makeConfiguration(
                id: snoozeID,
                meta: metadata,
                schedule: snoozeSchedule,
                preAlert: snoozeDuration
            )

            do {
                _ = try await AlarmManager.shared.schedule(id: snoozeID, configuration: snoozeConfig)
                scheduledIDs.append(snoozeID.uuidString)
            } catch {
                print("Failed to schedule snooze round \(round) for alarm \(mainID): \(error)")
            }
        }

        if !scheduledIDs.isEmpty {
            var mapping = snoozeMapping()
            mapping[mainID.uuidString] = scheduledIDs
            saveSnoozeMapping(mapping)
        }
    }

    // MARK: - Cancel

    private func cancelSystemAlarm(id: UUID) async {
        cancelSnoozeAlarms(for: id)

        do {
            try AlarmManager.shared.cancel(id: id)
        } catch {
            if !"\(error)".contains("unknownAlarm") {
                print("Failed to cancel alarm \(id): \(error)")
            }
        }
        locallyKnownScheduledIds.remove(id)
        lastPushedMetadata.removeValue(forKey: id)
    }

    private func cancelSnoozeAlarms(for mainID: UUID) {
        var mapping = snoozeMapping()
        guard let snoozeIDStrings = mapping[mainID.uuidString] else { return }

        for snoozeIDStr in snoozeIDStrings {
            guard let snoozeID = UUID(uuidString: snoozeIDStr) else { continue }
            try? AlarmManager.shared.cancel(id: snoozeID)
        }

        mapping.removeValue(forKey: mainID.uuidString)
        saveSnoozeMapping(mapping)
    }
}

//
//  AlarmPersistence.swift
//  PandaAlarm
//
//  Created by Gavin John on 7/30/26.
//

import Foundation

enum AlarmPersistence {
    private static let storeURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("alarms.json")
    }()

    static func save(_ alarms: IdentifiedSet<AlarmInstanceMetadata>) {
        do {
            let data = try JSONEncoder().encode(alarms)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            print("[AlarmPersistence] save failed: \(error)")
        }
    }

    static func load() -> IdentifiedSet<AlarmInstanceMetadata> {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode(IdentifiedSet<AlarmInstanceMetadata>.self, from: data)
        else { return IdentifiedSet() }
        return decoded
    }
}

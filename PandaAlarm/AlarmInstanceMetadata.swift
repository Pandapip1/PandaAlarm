//
//  AlarmMetadata.swift
//  PandaAlarm
//
//  Created by Gavin John on 7/29/26.
//

import AlarmKit

struct AlarmInstanceMetadata: AlarmMetadata, Identifiable {
    var id = UUID()
    var enabled: Bool
    var title: String
    var scheduledTime: DateComponents
    var snoozeDuration: Duration
    var task: AlarmTask
}

enum AlarmTask: Codable, Sendable {
    case none
}

extension AlarmTask: Equatable {
    nonisolated static func == (lhs: AlarmTask, rhs: AlarmTask) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        default:
            return false
        }
    }
}

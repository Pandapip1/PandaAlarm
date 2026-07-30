//
//  AlarmMetadata.swift
//  PandaAlarm
//
//  Created by Gavin John on 7/29/26.
//

import AlarmKit

nonisolated struct AlarmInstanceMetadata: AlarmMetadata, Identifiable, Equatable {
    var id = UUID()
    var enabled: Bool
    var title: String
    var scheduledTime: DateComponents
    var snoozeDuration: Duration
    var task: AlarmTask
}

nonisolated enum AlarmTask: Codable, Sendable, Equatable {
    case none
}

//
//  AlarmEntity.swift
//  PandaAlarm
//
//  Created by Gavin John on 7/29/26.
//

import SwiftUI
import AppIntents

struct AlarmEntity: AppEntity {
    let id: UUID
    
    static var typeDisplayName: LocalizedStringResource = "Alarm"
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Alarm")
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Alarm ID: \(id.uuidString)")
    }
    
    static var defaultQuery = AlarmEntityQuery()
}

struct AlarmEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [AlarmEntity] {
        return identifiers.map { AlarmEntity(id: $0) }
    }
}

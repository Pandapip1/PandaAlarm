//
//  ContentView.swift
//  PandaAlarm
//
//  Created by Gavin John on 7/29/26.
//

import SwiftUI
import AlarmKit

extension DateComponents: @retroactive Comparable {
    public static func < (lhs: DateComponents, rhs: DateComponents) -> Bool {
        let calendar = lhs.calendar ?? rhs.calendar ?? .current

        guard let lhsDate = calendar.date(from: lhs) else {
            preconditionFailure("Cannot compare DateComponents: lhs does not resolve to a valid Date in \(calendar). Ensure at minimum year/month/day (or hour/minute/second for a time-only comparison) are set.")
        }
        guard let rhsDate = calendar.date(from: rhs) else {
            preconditionFailure("Cannot compare DateComponents: rhs does not resolve to a valid Date in \(calendar). Ensure at minimum year/month/day (or hour/minute/second for a time-only comparison) are set.")
        }

        return lhsDate < rhsDate
    }
}

@Observable @MainActor
final class AlarmAuthorizationManager {
    private let manager = AlarmManager.shared
    private(set) var authState: AlarmManager.AuthorizationState = .notDetermined

    init() {
        authState = manager.authorizationState
        Task { await observeAuthorizationChanges() }
    }

    func observeAuthorizationChanges() async {
        for await state in manager.authorizationUpdates {
            authState = state
        }
    }
    
    func syncAuthState() {
        authState = manager.authorizationState
    }
    
    @discardableResult
    func requestAuthorization() async throws -> AlarmManager.AuthorizationState {
        let state = try await manager.requestAuthorization()
        authState = state
        return state
    }
}

struct ContentView: View {
    @State private var alarms: IdentifiedSet<AlarmInstanceMetadata> = IdentifiedSet.init();
    @State private var authManager = AlarmAuthorizationManager()
    
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if authManager.authState == .authorized {
            TabView {
                Tab("Alarms", systemImage: "alarm.fill") {
                    AlarmsView(alarms: $alarms)
                }
                
                
                Tab("Demos", systemImage: "puzzlepiece.fill") {
                    Text("Demos")
                }
                
                
                Tab("Settings", systemImage: "gearshape.fill") {
                    Text("Settings")
                }
            }
            .task { await monitorAlarms() }
            .onAppear() { checkAuthorization() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { authManager.syncAuthState() }
            }
        } else {
            VStack {
                Image(systemName: "shield.slash.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.tint)
                    .padding()
                // TODO: Use template for app name
                Text("Alarms permission has not been granted. Please go to Settings > Apps > Panda Alarm and manually enable it.")
                    .font(.callout)
                Button(
                    action: checkAuthorization
                ) {
                    Label("Check Again", systemImage: "arrow.clockwise")
                      .foregroundColor(.blue)
                      .padding()
                }
            }
            .padding()
            .onAppear() { checkAuthorization() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { authManager.syncAuthState() }
            }
        }
    }

    private func checkAuthorization() {
        authManager.syncAuthState()
        if authManager.authState == .notDetermined {
            Task {
                try? await authManager.requestAuthorization()
            }
        }
    }
    
    private func monitorAlarms() async {
        for await systemAlarms in AlarmManager.shared.alarmUpdates {
            let systemAlarmIds = systemAlarms.map { $0.id }
            let alarmIdsToAdd = alarms.ids.filter { !systemAlarmIds.contains($0) }
            let alarmIdsToUpdate = systemAlarmIds.filter { alarms[$0]?.enabled ?? false }
            let alarmIdsToRemove = systemAlarmIds.filter { !(alarms[$0]?.enabled ?? false) }
        }
    }
}


struct AlarmsView: View {
    @Binding var alarms: IdentifiedSet<AlarmInstanceMetadata>
 
    var body: some View {
        NavigationStack {
            Group {
                if alarms.isEmpty {
                    ContentUnavailableView(
                        "No alarms",
                        systemImage: "alarm",
                        description: Text("Tap + to add one.")
                    )
                } else {
                    List {
                        ForEach(alarms.sorted { $0.scheduledTime < $1.scheduledTime }, id: \.id) { alarm in
                            AlarmRow(alarm: Binding(
                                get: { alarms[alarm.id] ?? alarm },
                                set: { alarms[alarm.id] = $0 }
                            ))
                        }
                        .onDelete { indexSet in
                            let sorted = alarms.sorted { $0.scheduledTime < $1.scheduledTime }
                            indexSet.map { sorted[$0] }.forEach { alarms.remove($0) }
                        }
                    }
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addAlarm()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
 
    private func addAlarm() {
        alarms.insert(
            AlarmInstanceMetadata(
                enabled: false,
                title: "New alarm",
                scheduledTime: DateComponents(hour: 16, minute: 20),
                snoozeDuration: Duration.seconds(5 * 60),
                task: .none
            )
        )
    }
}
 
struct AlarmRow: View {
    @State private var localeRefreshID = UUID()
    @Binding var alarm: AlarmInstanceMetadata
 
    private var timeString: String {
        guard let date = Calendar.current.date(from: alarm.scheduledTime) else {
            return "PLACEHOLDER"
        }
        return date.formatted(date: .omitted, time: .shortened)
    }
 
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(alarm.title)
                    .font(.headline)
                    .foregroundStyle(alarm.enabled ? .primary : .secondary)
                Text(timeString)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
                        localeRefreshID = UUID()
                    }
                    .id(localeRefreshID)
            }
 
            Spacer()
 
            Toggle("", isOn: $alarm.enabled)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}

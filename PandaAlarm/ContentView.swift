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

struct ContentView: View {
    @State private var alarms: IdentifiedSet<AlarmInstanceMetadata> = IdentifiedSet.init();
    @State private var userAuthorized = false
    var body: some View {
        if self.userAuthorized {
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
        } else {
            VStack {
                Image(systemName: "shield.slash.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.tint)
                    .padding()
                // TODO: Use template for app name
                Text("Alarms permission has not been granted. Please go to Settings > Apps > Panda Alarm and manually enable it.")
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
        }
    }
    
    private func checkAuthorization() {
        switch AlarmManager.shared.authorizationState {
        case .notDetermined:
            self.userAuthorized = false;
            Task {
                let _ = try await AlarmManager.shared.requestAuthorization()
                checkAuthorization()
            }
        case .denied:
            self.userAuthorized = false;
            break
        case .authorized:
            self.userAuthorized = true;
            break
        @unknown default:
            self.userAuthorized = false;
            break
        }
    }
    
    private func monitorAlarms() async {
        for await systemAlarms in AlarmManager.shared.alarmUpdates {
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
                ToolbarItem(placement: .navigationBarTrailing) {
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
    @Binding var alarm: AlarmInstanceMetadata
 
    private var timeString: String {
        alarm.scheduledTime.description
    }
 
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeString)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(alarm.enabled ? .primary : .secondary)
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

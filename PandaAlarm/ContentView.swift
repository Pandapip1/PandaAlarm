//
//  ContentView.swift
//  PandaAlarm
//
//  Created by Gavin John on 7/29/26.
//

import SwiftUI

struct ContentView: View {
    @State private var alarms: [AlarmInstanceMetadata] = [
        AlarmInstanceMetadata(enabled: true, title: "Wake up", scheduledTime: DateComponents(hour: 7, minute: 30), snoozeDuration: Duration.seconds(5 * 60), task: .none),
        AlarmInstanceMetadata(enabled: true, title: "Weekend", scheduledTime: DateComponents(hour: 9, minute: 30), snoozeDuration: Duration.seconds(5 * 60), task: .none),
        AlarmInstanceMetadata(enabled: false, title: "Nap reminder", scheduledTime: DateComponents(hour: 13, minute: 45), snoozeDuration: Duration.seconds(5 * 60), task: .none)
    ];
    var body: some View {
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
        };
    }   
}


struct AlarmsView: View {
    @Binding var alarms: [AlarmInstanceMetadata]
 
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
                        ForEach($alarms) { $alarm in
                            AlarmRow(alarm: $alarm)
                        }
                        .onDelete { indexSet in
                            alarms.remove(atOffsets: indexSet)
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
        alarms.append(
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

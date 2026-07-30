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
    @State private var isReconciling = false
    @State private var reconcilePending = false
    
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
            .onChange(of: alarms) { _, _ in
                Task { await requestReconcile() }
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
        for await _ in AlarmManager.shared.alarmUpdates {
            await requestReconcile()
        }
    }

    private func requestReconcile() async {
        if isReconciling {
            reconcilePending = true
            return
        }
        isReconciling = true
        repeat {
            reconcilePending = false
            do {
                let systemAlarms = try AlarmManager.shared.alarms
                await reconcile(against: systemAlarms)
            } catch {
                print("Failed to fetch system alarms: \(error)")
            }
        } while reconcilePending
        isReconciling = false
    }

    private func reconcile(against systemAlarms: [Alarm]) async {
        let systemAlarmIds = Set(systemAlarms.map { $0.id })
        let locallyEnabledIds = Set(alarms.ids.filter { alarms[$0]?.enabled ?? false })
        let alarmIdsToAdd = locallyEnabledIds.subtracting(systemAlarmIds)
        let alarmIdsToUpdate = locallyEnabledIds.intersection(systemAlarmIds)
        let alarmIdsToRemove = systemAlarmIds.subtracting(locallyEnabledIds)

        for id in alarmIdsToAdd.union(alarmIdsToUpdate) {
            guard let metadata = alarms[id] else { continue }
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
        } catch {
            print("Failed to schedule alarm \(id): \(error)")
        }
    }

    private func cancelSystemAlarm(id: UUID) async {
        do {
            try AlarmManager.shared.cancel(id: id)
        } catch {
            print("Failed to cancel alarm \(id): \(error)")
        }
    }
}


struct AlarmsView: View {
    @Binding var alarms: IdentifiedSet<AlarmInstanceMetadata>
    @State private var editingAlarm: AlarmInstanceMetadata?
 
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
                            AlarmRow(
                                alarm: Binding(
                                    get: { alarms[alarm.id] ?? alarm },
                                    set: { alarms[alarm.id] = $0 }
                                ),
                                onEdit: { editingAlarm = alarms[alarm.id] ?? alarm }
                            )
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
            .sheet(item: $editingAlarm) { alarm in
                AlarmEditorView(
                    alarm: Binding(
                        get: { alarms[alarm.id] ?? alarm },
                        set: { alarms[alarm.id] = $0 }
                    )
                )
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
    var onEdit: () -> Void
 
    private var timeString: String {
        guard let date = Calendar.current.date(from: alarm.scheduledTime) else {
            return "PLACEHOLDER"
        }
        return date.formatted(date: .omitted, time: .shortened)
    }
 
    var body: some View {
        HStack {
            Button(action: onEdit) {
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
            }
            .buttonStyle(.plain)
 
            Spacer()
 
            Toggle("", isOn: $alarm.enabled)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

struct AlarmEditorView: View {
    @Binding var alarm: AlarmInstanceMetadata
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var time: Date
    @State private var snoozeMinutes: Int

    init(alarm: Binding<AlarmInstanceMetadata>) {
        self._alarm = alarm
        let initial = alarm.wrappedValue
        _title = State(initialValue: initial.title)
        _time = State(initialValue: Calendar.current.date(from: initial.scheduledTime) ?? Date())
        _snoozeMinutes = State(initialValue: Int(initial.snoozeDuration.components.seconds / 60))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Alarm name", text: $title)
                }

                Section("Time") {
                    DatePicker(
                        "Time",
                        selection: $time,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                }

                Section("Snooze") {
                    Stepper(
                        "Snooze: \(snoozeMinutes) min",
                        value: $snoozeMinutes,
                        in: 0...30
                    )
                }
            }
            .navigationTitle("Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        alarm.title = title
        alarm.scheduledTime = Calendar.current.dateComponents([.hour, .minute], from: time)
        alarm.snoozeDuration = .seconds(snoozeMinutes * 60)
        dismiss()
    }
}

#Preview {
    ContentView()
}

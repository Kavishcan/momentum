import AppKit
import MomentumCore
import SwiftData
import SwiftUI

struct MomentumRoot: View {
    @StateObject private var store: MomentumStore
    @ObservedObject var focus: FocusController
    @ObservedObject var reminders: ReminderService
    @State private var tab = 0
    @AppStorage("night.enabled") private var nightEnabled = false
    @AppStorage("night.hour") private var nightHour = 22
    @AppStorage("night.minute") private var nightMinute = 0

    init(container: ModelContainer, focus: FocusController, reminders: ReminderService) {
        _store = StateObject(wrappedValue: MomentumStore(container: container))
        self.focus = focus
        self.reminders = reminders
    }

    var body: some View {
        MomentumPopover(tab: $tab) {
            if tab == 0 { TodayView(store: store, focus: focus) }
            else { NightView(store: store, reminders: reminders) }
        }
        .onAppear { refresh() }
        .onReceive(focus.$now) { now in
            if store.dayKey != DayClock.dayKey(for: now) || store.nightKey != DayClock.nightKey(for: now) {
                store.refresh(now: now)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)) { _ in refresh() }
        .onChange(of: nightEnabled) { _, _ in configureReminder() }
        .onChange(of: nightHour) { _, _ in configureReminder() }
        .onChange(of: nightMinute) { _, _ in configureReminder() }
        .alert("Something needs attention", isPresented: Binding(
            get: { store.errorMessage != nil || focus.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil; focus.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil; focus.errorMessage = nil }
        } message: { Text(store.errorMessage ?? focus.errorMessage ?? "") }
    }

    private func refresh() { store.refresh(); configureReminder() }
    private func configureReminder() { reminders.configure(enabled: nightEnabled, hour: nightHour, minute: nightMinute) }
}

/// Own the menu extra's ideal dimensions; a maximum alone lets a ScrollView collapse.
struct MomentumPopover<Content: View>: View {
    @Binding var tab: Int
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Momentum").font(.system(size: 24, weight: .medium))
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .foregroundStyle(MomentumTheme.muted)
                }
                Spacer()
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 24, weight: .light)).accessibilityHidden(true)
            }
            Picker("Your day", selection: $tab) {
                Text("Today").tag(0)
                Text("Night Shutdown").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }.padding(.bottom, 4)
            }
            // MenuBarExtra may measure the minimum size first. A max-only frame
            // reports zero here, hiding the entire task/timer/checklist region.
            .frame(maxWidth: .infinity)
            .frame(height: 400)

            HStack {
                Text("A little less friction. A little more intention.")
                    .font(.system(size: 11)).foregroundStyle(MomentumTheme.muted)
                Spacer(minLength: 4)
                Button("Quit") { NSApp.terminate(nil) }
                    .font(.system(size: 12)).keyboardShortcut("q")
            }
        }
        .padding(24)
        .frame(width: 424, height: 600)
        .font(.system(size: 14))
        .foregroundStyle(MomentumTheme.ink)
        .background(MomentumTheme.canvas)
        .tint(MomentumTheme.primary)
        .preferredColorScheme(.light)
    }
}

struct TodayView: View {
    @ObservedObject var store: MomentumStore
    @ObservedObject var focus: FocusController
    @State private var newTask = ""
    @State private var selectedTaskID: UUID?
    @State private var editingTask: DailyTask?

    private var selectedTitle: String {
        store.tasks.first { $0.id == selectedTaskID }?.title ?? "One small step"
    }

    var body: some View {
        Card {
            HStack {
                Text("Daily Three").font(.system(size: 18, weight: .medium))
                Spacer()
                Text("\(store.tasks.filter(\.isComplete).count) / 3 done")
                    .font(.system(size: 12)).foregroundStyle(MomentumTheme.muted)
            }
            Text("What would make today feel worthwhile?").foregroundStyle(MomentumTheme.muted)
            ForEach(store.tasks) { task in
                HStack(spacing: 8) {
                    Button { store.toggle(task) } label: {
                        Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20)).frame(width: 32, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(task.isComplete ? "Mark \(task.title) incomplete" : "Complete \(task.title)")
                    Text(task.title)
                        .strikethrough(task.isComplete)
                        .foregroundStyle(task.isComplete ? MomentumTheme.muted : MomentumTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { selectedTaskID = task.id } label: {
                        Image(systemName: "arrow.down.right").frame(width: 28, height: 32)
                    }.buttonStyle(.plain).help("Choose for Just Start")
                        .accessibilityLabel("Choose \(task.title) for focus")
                    Button { editingTask = task } label: {
                        Image(systemName: "pencil").frame(width: 28, height: 32)
                    }.buttonStyle(.plain).help("Edit task").accessibilityLabel("Edit \(task.title)")
                }
            }
            if store.tasks.count < 3 {
                HStack(spacing: 8) {
                    TextField(store.tasks.isEmpty ? "One small, specific task…" : "Add a task…", text: $newTask)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("New daily task")
                        .onSubmit(addTask)
                    Button("Add", action: addTask)
                        .disabled(newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Text("Enough for today. Make room by editing a task.")
                    .font(.system(size: 12)).foregroundStyle(MomentumTheme.muted)
            }
        }

        Card {
            HStack {
                Text("Just Start").font(.system(size: 18, weight: .medium))
                Spacer()
                Image(systemName: "timer").accessibilityHidden(true)
            }
            if focus.session.phase == .idle {
                Text("You only need to begin.").foregroundStyle(MomentumTheme.muted)
                Picker("Focus on", selection: $selectedTaskID) {
                    Text("One small step").tag(nil as UUID?)
                    ForEach(store.tasks) { task in Text(task.title).tag(Optional(task.id)) }
                }
                HStack(spacing: 8) {
                    Button("Start 10 min") { focus.start(minutes: 10, title: selectedTitle) }
                    Button("Start 25 min") { focus.start(minutes: 25, title: selectedTitle) }
                }.buttonStyle(PrimaryButtonStyle())
            } else {
                Text(focus.session.taskTitle).lineLimit(3)
                Text(focus.session.clockText(at: focus.now))
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .monospacedDigit().frame(maxWidth: .infinity)
                    .accessibilityLabel("Time remaining")
                    .accessibilityValue(focus.session.clockText(at: focus.now))
                switch focus.session.phase {
                case .running:
                    HStack {
                        Button("Pause") { focus.pause() }.buttonStyle(PrimaryButtonStyle())
                        Button("End session") { focus.reset() }
                    }
                case .paused:
                    Text("Paused. Come back when you’re ready.").foregroundStyle(MomentumTheme.muted)
                    HStack {
                        Button("Resume") { focus.resume() }.buttonStyle(PrimaryButtonStyle())
                        Button("End session") { focus.reset() }
                    }
                case .finished:
                    Text("That counts. Take a breath before the next thing.").foregroundStyle(MomentumTheme.muted)
                    Button("Done") { focus.reset() }.buttonStyle(PrimaryButtonStyle())
                case .idle: EmptyView()
                }
            }
        }
        .sheet(item: $editingTask) { task in
            EditTextSheet(title: "Edit task", initialValue: task.title,
                          onSave: { store.rename(task, to: $0) }, onDelete: { store.delete(task) })
        }
        .onChange(of: store.dayKey) { _, _ in selectedTaskID = nil }
        .onChange(of: store.tasks.map(\.id)) { _, ids in
            if let selectedTaskID, !ids.contains(selectedTaskID) { self.selectedTaskID = nil }
        }
    }

    private func addTask() {
        store.addTask(newTask)
        if store.errorMessage == nil { newTask = "" }
    }
}

struct NightView: View {
    @ObservedObject var store: MomentumStore
    @ObservedObject var reminders: ReminderService
    @AppStorage("night.enabled") private var enabled = false
    @AppStorage("night.hour") private var hour = 22
    @AppStorage("night.minute") private var minute = 0
    @State private var newStep = ""
    @State private var editingStep: RoutineStep?

    private var time: Binding<Date> {
        Binding(get: {
            Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour, minute: minute)) ?? .now
        }, set: { date in
            hour = Calendar.current.component(.hour, from: date)
            minute = Calendar.current.component(.minute, from: date)
        })
    }

    var body: some View {
        Card {
            Text("Land the day.").font(.system(size: 24, weight: .regular))
            Text("Make the next choice easy: put your phone away before you get into bed.")
                .foregroundStyle(MomentumTheme.muted).fixedSize(horizontal: false, vertical: true)
            DatePicker("Wind-down reminder", selection: time, displayedComponents: .hourAndMinute)
            if enabled {
                Button("Turn reminders off") { enabled = false }
            } else {
                Button("Enable daily reminder") {
                    Task {
                        if await reminders.requestPermission() { enabled = true }
                    }
                }.buttonStyle(PrimaryButtonStyle()).disabled(reminders.isWorking)
            }
            Text(reminders.status).font(.system(size: 12)).foregroundStyle(MomentumTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        Card {
            HStack {
                Text("Your shutdown routine").font(.system(size: 18, weight: .medium))
                Spacer()
                Text("\(store.steps.filter { $0.completedNightKey == store.nightKey }.count)/\(store.steps.count)")
                    .foregroundStyle(MomentumTheme.muted)
                    .accessibilityLabel("Completed routine steps")
            }
            ForEach(store.steps) { step in
                HStack(spacing: 8) {
                    let done = step.completedNightKey == store.nightKey
                    Button { store.toggle(step) } label: {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20)).frame(width: 32, height: 36)
                    }.buttonStyle(.plain)
                        .accessibilityLabel(done ? "Uncheck \(step.title)" : "Complete \(step.title)")
                    Text(step.title).strikethrough(done)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { editingStep = step } label: {
                        Image(systemName: "pencil").frame(width: 28, height: 32)
                    }.buttonStyle(.plain).help("Edit step").accessibilityLabel("Edit \(step.title)")
                }
            }
            if store.steps.count < 10 {
                HStack {
                    TextField("Add a wind-down step…", text: $newStep)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("New routine step").onSubmit(addStep)
                    Button("Add", action: addStep)
                        .disabled(newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            Text("Checks reset at noon, so after midnight still counts as tonight.")
                .font(.system(size: 12)).foregroundStyle(MomentumTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if !store.steps.isEmpty && store.steps.allSatisfy({ $0.completedNightKey == store.nightKey }) {
                Label("You’re ready to switch off. Rest well.", systemImage: "moon")
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .sheet(item: $editingStep) { step in
            EditTextSheet(title: "Edit routine step", initialValue: step.title,
                          onSave: { store.rename(step, to: $0) }, onDelete: { store.delete(step) })
        }
    }

    private func addStep() {
        store.addStep(newStep)
        if store.errorMessage == nil { newStep = "" }
    }
}

struct EditTextSheet: View {
    let title: String
    @State private var text: String
    let onSave: (String) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    init(title: String, initialValue: String, onSave: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.title = title
        _text = State(initialValue: initialValue)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title).font(.headline)
            TextField("Title", text: $text).textFieldStyle(.roundedBorder)
            HStack {
                Button("Delete", role: .destructive) { confirmDelete = true }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { onSave(text); dismiss() }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 360)
            .confirmationDialog("Delete this item?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) { onDelete(); dismiss() }
                Button("Cancel", role: .cancel) {}
            }
    }
}

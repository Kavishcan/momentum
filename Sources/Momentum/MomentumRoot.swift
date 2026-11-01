import AppKit
import MomentumCore
import SwiftUI

struct MomentumRoot: View {
    @ObservedObject var workspace: Workspace
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                Label("Momentum", systemImage: "circle.lefthalf.filled").font(.system(size: 18, weight: .semibold))
                    .padding(.bottom, 12)
                ForEach(WorkspacePage.allCases) { page in
                    Button { workspace.page = page } label: {
                        Label(page.rawValue, systemImage: page.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 11)
                            .background(workspace.page == page ? Color.primary.opacity(0.08) : .clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).accessibilityAddTraits(workspace.page == page ? .isSelected : [])
                }
                Spacer()
                Text("Small steps.\nA calmer finish.").font(.callout).foregroundStyle(.secondary).lineSpacing(4)
            }.padding(20).frame(width: 188)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    switch workspace.page {
                    case .today: TodayView(store: workspace.store, focus: workspace.focus)
                    case .shutdown: NightView(store: workspace.store, reminders: workspace.reminders)
                    case .history: HistoryView(store: workspace.store)
                    case .settings: DataSettingsView(store: workspace.store)
                    }
                }.padding(28).frame(maxWidth: .infinity, alignment: .topLeading)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 840, minHeight: 620)
        .background(MomentumTheme.canvas)
        .tint(.primary)
        .onAppear { workspace.activate() }
        .onReceive(NotificationCenter.default.publisher(for: .momentumOpenNight)) { _ in
            workspace.page = .shutdown; openWindow(id: "dashboard")
        }
        .modifier(WorkspaceErrorPresenter(store: workspace.store, focus: workspace.focus))
    }
}
struct WorkspaceErrorPresenter: ViewModifier {
    @ObservedObject var store: MomentumStore
    @ObservedObject var focus: FocusController
    func body(content: Content) -> some View {
        content.alert("The change needs attention", isPresented: Binding(
            get: { store.errorMessage != nil || focus.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil; focus.errorMessage = nil } }
        )) { Button("OK") { store.errorMessage = nil; focus.errorMessage = nil } }
        message: { Text(store.errorMessage ?? focus.errorMessage ?? "") }
    }
}
struct PageHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 30, weight: .semibold))
            Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
struct TodayView: View {
    @ObservedObject var store: MomentumStore
    @ObservedObject var focus: FocusController
    @State private var newTask = ""
    @State private var editing: MomentumTask?
    @State private var selectedID: UUID?
    var body: some View {
        PageHeading(title: "A little progress, on purpose.",
                    subtitle: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        HStack(alignment: .top, spacing: 20) {
            Card {
                HStack {
                    Text("Daily Three").font(.title3.weight(.semibold))
                    Spacer()
                    Text("\(store.tasks.filter(\.isComplete).count)/3 complete").font(.caption).foregroundStyle(.secondary)
                }
                Text("Choose what matters. Three is enough.").foregroundStyle(.secondary)
                if store.tasks.isEmpty {
                    Label("Start with one small, specific task.", systemImage: "plus.circle.dashed")
                        .foregroundStyle(.secondary).padding(.vertical, 12)
                }
                ForEach(store.tasks) { task in
                    HStack(alignment: .center, spacing: 10) {
                        Button { store.toggle(task) } label: {
                            Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                                .font(.title3).frame(width: 30, height: 36)
                        }.buttonStyle(.plain).accessibilityLabel("\(task.isComplete ? "Uncomplete" : "Complete") \(task.title)")
                        Text(task.title).strikethrough(task.isComplete)
                            .foregroundStyle(task.isComplete ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                        Button { selectedID = task.id; focus.start(minutes: 10, title: task.title) } label: {
                            Image(systemName: "play").frame(width: 28, height: 36)
                        }.buttonStyle(.plain).help("Start a 10-minute focus session")
                            .accessibilityLabel("Focus on \(task.title)")
                            .disabled(focus.session.phase == .running || focus.session.phase == .paused)
                        Button { editing = task } label: { Image(systemName: "pencil").frame(width: 28, height: 36) }
                            .buttonStyle(.plain).accessibilityLabel("Edit \(task.title)")
                    }
                    Divider()
                }
                TextField("What’s your next small step?", text: $newTask)
                    .textFieldStyle(.roundedBorder).onSubmit(add)
                    .accessibilityIdentifier("daily-task-input").disabled(store.tasks.count >= 3)
                HStack {
                    Text("\(store.tasks.count)/3 tasks").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Add task", action: add)
                        .disabled(newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.tasks.count >= 3)
                }
            }.frame(minWidth: 260, maxWidth: .infinity)
            FocusPanel(store: store, focus: focus, selectedID: $selectedID).frame(width: 272)
        }
        Label("Everything is saved on this Mac. Come back whenever you’re ready.", systemImage: "internaldrive")
            .font(.callout).foregroundStyle(.secondary)
        .sheet(item: $editing) { task in
            EditTextSheet(title: "Edit task", initialValue: task.title, onSave: {
                try store.database.renameTask(task.id, to: $0); store.refresh()
            }, onDelete: { try store.database.deleteTask(task.id); store.refresh() })
        }
        .onChange(of: store.tasks.map(\.id)) { _, ids in if let selectedID, !ids.contains(selectedID) { self.selectedID = nil } }
    }
    private func add() { if store.addTask(newTask) { newTask = "" } }
}
struct FocusPanel: View {
    @ObservedObject var store: MomentumStore
    @ObservedObject var focus: FocusController
    @Binding var selectedID: UUID?
    @State private var confirmEnd = false
    var body: some View {
        Card {
            Label("Just Start", systemImage: "timer").font(.title3.weight(.semibold))
            if focus.session.phase == .idle {
                Text("You only need to begin.").foregroundStyle(.secondary)
                Picker("Focus on", selection: $selectedID) {
                    Text("One small step").tag(nil as UUID?)
                    ForEach(store.tasks) { Text($0.title).tag(Optional($0.id)) }
                }.pickerStyle(.menu)
                Button("Start 10 minutes") { start(10) }.buttonStyle(PrimaryButtonStyle())
                Button("Start 25 minutes") { start(25) }.frame(maxWidth: .infinity)
            } else {
                Text(focus.session.taskTitle).font(.headline).fixedSize(horizontal: false, vertical: true)
                Text(focus.session.clockText(at: focus.now))
                    .font(.system(size: 46, weight: .light, design: .rounded)).monospacedDigit()
                    .frame(maxWidth: .infinity).accessibilityLabel("Time remaining")
                    .accessibilityValue(focus.session.clockText(at: focus.now))
                ProgressView(value: 1 - focus.session.remaining(at: focus.now) / focus.session.duration)
                    .accessibilityLabel("Session progress")
                if focus.session.phase == .running {
                    Button("Pause") { focus.pause() }.buttonStyle(PrimaryButtonStyle())
                } else if focus.session.phase == .paused {
                    Text("Paused. Take the time you need.").foregroundStyle(.secondary)
                    Button("Resume") { focus.resume() }.buttonStyle(PrimaryButtonStyle())
                } else {
                    Label("That counts. Take a breath.", systemImage: "checkmark.circle")
                    Button("Done") { focus.reset() }.buttonStyle(PrimaryButtonStyle())
                }
                if focus.session.phase != .finished {
                    Button("End session") { confirmEnd = true }.frame(maxWidth: .infinity)
                }
            }
        }.confirmationDialog("End this focus session?", isPresented: $confirmEnd) {
            Button("End session", role: .destructive) { focus.reset() }
            Button("Keep going", role: .cancel) {}
        } message: { Text("An unfinished session won’t be added to your completed history.") }
    }
    private func start(_ minutes: Int) { focus.start(minutes: minutes, title: store.tasks.first { $0.id == selectedID }?.title ?? "One small step") }
}
struct NightView: View {
    @ObservedObject var store: MomentumStore
    @ObservedObject var reminders: ReminderCoordinator
    @State private var draft = NightSettings()
    @State private var saving = false
    @State private var newStep = ""
    @State private var editing: ShutdownStep?
    private var time: Binding<Date> {
        Binding(get: { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: draft.hour, minute: draft.minute)) ?? .now },
                set: { draft.hour = Calendar.current.component(.hour, from: $0); draft.minute = Calendar.current.component(.minute, from: $0) })
    }
    var body: some View {
        PageHeading(title: "Land the day.", subtitle: "Make the next choice easy. Park your phone away from bed and give yourself permission to stop.")
        Card {
            Text("Your evening reminder").font(.title3.weight(.semibold))
            Toggle("Remind me to wind down", isOn: $draft.enabled)
            DatePicker("At", selection: time, displayedComponents: .hourAndMinute).disabled(!draft.enabled)
            HStack {
                Button(saving ? "Saving…" : "Save reminder") { save() }.disabled(saving || reminders.busy || draft == store.settings)
                Button("Send test") { Task { do { try await reminders.test() } catch { store.errorMessage = error.localizedDescription } } }
                    .disabled(saving || reminders.busy)
                Button("Refresh status") { reminders.synchronize() }.disabled(reminders.busy)
            }
            if draft != store.settings { Text("You have unsaved reminder changes.").font(.caption).foregroundStyle(.secondary) }
            Text(reminders.status).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        Card {
            HStack {
                Text("Your shutdown routine").font(.title3.weight(.semibold)); Spacer()
                Text("\(store.steps.filter(\.isComplete).count)/\(store.steps.count) done").foregroundStyle(.secondary)
            }
            ForEach(store.steps) { step in
                HStack {
                    Button { store.toggle(step) } label: {
                        Image(systemName: step.isComplete ? "checkmark.circle.fill" : "circle").font(.title3).frame(width: 32, height: 36)
                    }.buttonStyle(.plain).accessibilityLabel("\(step.isComplete ? "Uncheck" : "Complete") \(step.title)")
                    Text(step.title).strikethrough(step.isComplete).frame(maxWidth: .infinity, alignment: .leading)
                    Button { editing = step } label: { Image(systemName: "pencil").frame(width: 32, height: 36) }
                        .buttonStyle(.plain).accessibilityLabel("Edit \(step.title)")
                }
            }
            HStack {
                TextField("Add a wind-down step…", text: $newStep).textFieldStyle(.roundedBorder).onSubmit(addStep)
                Button("Add step", action: addStep).disabled(newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.steps.count >= 10)
            }
            Text("Checks reset at noon, so after midnight still counts as tonight.").font(.caption).foregroundStyle(.secondary)
            if !store.steps.isEmpty && store.steps.allSatisfy(\.isComplete) {
                Label("You’re ready to switch off. Rest well.", systemImage: "moon.stars").font(.headline)
            }
        }
        .onAppear { draft = store.settings }
        .sheet(item: $editing) { step in
            EditTextSheet(title: "Edit routine step", initialValue: step.title, onSave: {
                try store.database.renameStep(step.id, to: $0); store.refresh()
            }, onDelete: { try store.database.deleteStep(step.id); store.refresh() })
        }
    }
    private func addStep() { if store.addStep(newStep) { newStep = "" } }
    private func save() {
        saving = true
        let value = draft
        Task {
            defer { saving = false }
            do {
                if value.enabled {
                    guard try await reminders.requestPermission() else {
                        store.errorMessage = "Allow Momentum in System Settings → Notifications, then save again. Your previous reminder setting is unchanged."
                        return
                    }
                }
                if store.saveSettings(value) { reminders.synchronize() }
            } catch { store.errorMessage = error.localizedDescription }
        }
    }
}
struct EditTextSheet: View {
    let title: String
    @State private var text: String
    let onSave: (String) throws -> Void
    let onDelete: () throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var error: String?
    init(title: String, initialValue: String, onSave: @escaping (String) throws -> Void, onDelete: @escaping () throws -> Void) {
        self.title = title; _text = State(initialValue: initialValue); self.onSave = onSave; self.onDelete = onDelete
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title).font(.title3.weight(.semibold))
            TextField("Title", text: $text).textFieldStyle(.roundedBorder).onSubmit(save)
            if let error { Text(error).font(.callout).foregroundStyle(.secondary) }
            HStack {
                Button("Delete", role: .destructive) { confirmDelete = true }; Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save", action: save).keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 200)
            }
        }.padding(28).frame(width: 420)
            .confirmationDialog("Delete this item?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) { do { try onDelete(); dismiss() } catch { self.error = error.localizedDescription } }
                Button("Cancel", role: .cancel) {}
            }
    }
    private func save() { do { try onSave(text); dismiss() } catch { self.error = error.localizedDescription } }
}

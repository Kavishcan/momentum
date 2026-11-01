import AppKit
import MomentumCore
import SwiftUI

struct MomentumRoot: View {
    @ObservedObject var workspace: Workspace
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    MomentumMark()
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Momentum").font(.system(size: 14, weight: .semibold))
                        Text("Personal workspace").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 12).padding(.top, 24).padding(.bottom, 30)
                Text("WORKSPACE").font(.system(size: 10, weight: .medium)).tracking(0.8)
                    .foregroundStyle(.secondary).padding(.horizontal, 12).padding(.bottom, 10)
                VStack(spacing: 3) {
                    ForEach(WorkspacePage.allCases) { page in
                        SidebarPageButton(page: page, selected: workspace.page == page) { workspace.page = page }
                    }
                }
                Spacer()
                Divider().padding(.bottom, 14)
                Label("On this Mac", systemImage: "internaldrive")
                    .font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 12)
                Text("Small steps, every day.").font(.system(size: 11)).foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 18)
            }.padding(.horizontal, 12).frame(width: 212).frame(maxHeight: .infinity)
                .background(MomentumTheme.sidebar)
            Divider()
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("Momentum").foregroundStyle(.secondary)
                    Text("/").foregroundStyle(.tertiary)
                    Label(workspace.page.rawValue, systemImage: workspace.page.symbol)
                    Spacer()
                    Button { workspace.activate() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain).help("Refresh your workspace").accessibilityLabel("Refresh workspace")
                }.font(.system(size: 12)).padding(.horizontal, 24).frame(height: 44)
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        switch workspace.page {
                        case .today: TodayView(store: workspace.store, focus: workspace.focus)
                        case .shutdown: NightView(store: workspace.store, reminders: workspace.reminders)
                        case .history: HistoryView(store: workspace.store)
                        case .settings: DataSettingsView(store: workspace.store)
                        }
                    }.padding(.horizontal, 32).padding(.top, 28).padding(.bottom, 48)
                        .frame(maxWidth: 960, alignment: .topLeading).frame(maxWidth: .infinity)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 840, minHeight: 620)
        .foregroundStyle(MomentumTheme.ink)
        .background(MomentumTheme.canvas)
        .tint(MomentumTheme.ink)
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
struct SidebarPageButton: View {
    let page: WorkspacePage
    let selected: Bool
    let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: page.symbol).frame(width: 18).foregroundStyle(.secondary)
                Text(page.rawValue).font(.system(size: 13, weight: selected ? .medium : .regular))
                Spacer(minLength: 0)
            }.padding(.horizontal, 12).frame(height: 34)
                .background(selected ? MomentumTheme.selection : (hovered ? MomentumTheme.hover : .clear),
                            in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hovered = $0 }
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct PageHeading: View {
    let title: String
    let subtitle: String
    var symbol: String = "doc.text"
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 34, weight: .light))
                .foregroundStyle(MomentumTheme.ink).frame(height: 44).accessibilityHidden(true)
            Text(title).font(.system(size: 36, weight: .bold)).tracking(-0.7)
            Text(subtitle).font(.system(size: 14)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
        PageHeading(title: "Today", subtitle: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()), symbol: "calendar")
        HStack(alignment: .top, spacing: 28) {
            Card {
                HStack {
                    Text("Daily Three").font(.system(size: 16, weight: .semibold))
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
                            Image(systemName: task.isComplete ? "checkmark.square.fill" : "square")
                                .font(.system(size: 17)).frame(width: 26, height: 36)
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
                if store.tasks.count < 3 {
                    HStack(spacing: 10) {
                        Image(systemName: "plus").foregroundStyle(.secondary).frame(width: 26)
                        TextField("Add a task…", text: $newTask).textFieldStyle(.plain).onSubmit(add)
                            .accessibilityLabel("New daily task").accessibilityIdentifier("daily-task-input")
                        Button("Add", action: add).controlSize(.small)
                            .disabled(newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }.padding(.vertical, 8)
                } else {
                    Text("Three priorities. That’s enough for today.").font(.callout).foregroundStyle(.secondary)
                }
                Divider()
            }.frame(minWidth: 260, maxWidth: .infinity)
            FocusPanel(store: store, focus: focus, selectedID: $selectedID).frame(width: 244)
        }
        Label("One small step is enough to begin.", systemImage: "leaf")
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
        Card(style: .callout) {
            Label("Just Start", systemImage: "timer").font(.system(size: 15, weight: .semibold))
            if focus.session.phase == .idle {
                Text("You only need to begin.").foregroundStyle(.secondary)
                Picker("Focus on", selection: $selectedID) {
                    Text("One small step").tag(nil as UUID?)
                    ForEach(store.tasks) { Text($0.title).tag(Optional($0.id)) }
                }.pickerStyle(.menu)
                Button("Start 10 minutes") { start(10) }.buttonStyle(PrimaryButtonStyle())
                Button("Start 25 minutes") { start(25) }.buttonStyle(DocumentButtonStyle())
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
        PageHeading(title: "Night Shutdown", subtitle: "A small ritual to close the day.", symbol: "moon")
        Card(style: .callout) {
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
                        Image(systemName: step.isComplete ? "checkmark.square.fill" : "square").font(.title3).frame(width: 32, height: 36)
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

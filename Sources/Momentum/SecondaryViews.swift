import AppKit
import MomentumCore
import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: MomentumStore
    @State private var date = Date.now
    @State private var tasks: [MomentumTask] = []
    var body: some View {
        PageHeading(title: "History", subtitle: "The small steps you’ve already taken.", symbol: "clock.arrow.circlepath")
        Card {
            HStack {
                Text("Daily tasks").font(.title3.weight(.semibold)); Spacer()
                DatePicker("Day", selection: $date, in: ...Date.now, displayedComponents: .date)
            }
            if tasks.isEmpty { Text("No tasks saved for this day.").foregroundStyle(.secondary) }
            ForEach(tasks) { task in
                HStack {
                    Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    Text(task.title).frame(maxWidth: .infinity, alignment: .leading)
                    if task.dayKey != store.dayKey {
                        Button("Add to today") { if store.addTask(task.title) { load() } }.disabled(store.tasks.count >= 3)
                    }
                }.padding(.vertical, 4)
            }
        }
        Card {
            Text("Completed focus sessions").font(.title3.weight(.semibold))
            if store.history.isEmpty { Text("Your completed sessions will appear here.").foregroundStyle(.secondary) }
            ForEach(store.history) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.title)
                        Text(record.finishedAt, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(record.duration / 60)) min").monospacedDigit().foregroundStyle(.secondary)
                }
                Divider()
            }
        }
        .onAppear(perform: load)
        .onChange(of: date) { _, _ in load() }
    }
    private func load() {
        do { tasks = try store.database.tasks(on: DayClock.dayKey(for: date)) }
        catch { store.errorMessage = error.localizedDescription }
    }
}
struct DataSettingsView: View {
    @ObservedObject var store: MomentumStore
    @State private var status = ""
    var body: some View {
        PageHeading(title: "Settings", subtitle: "Your workspace, your preferences.", symbol: "slider.horizontal.3")
        Card {
            Label("Local storage", systemImage: "internaldrive").font(.title3.weight(.semibold))
            Text("Tasks, settings, routines, and focus sessions are saved automatically in one local SQLite database. No account or cloud service is required.")
                .foregroundStyle(.secondary)
            Text(store.database.url.path).font(.caption.monospaced()).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Create database backup…", action: backup)
                Button("Show data folder") { NSWorkspace.shared.activateFileViewerSelecting([store.database.url]) }
                Button("Check database") {
                    do {
                        let result = try store.database.integrityCheck()
                        status = result == "ok" ? "Database check passed." : "Database check: \(result)"
                    } catch { store.errorMessage = error.localizedDescription }
                }
            }
            if !status.isEmpty { Text(status).font(.callout).foregroundStyle(.secondary).textSelection(.enabled) }
        }
        Card {
            Text("A few useful details").font(.title3.weight(.semibold))
            Label("The timer continues when you close the window.", systemImage: "timer")
            Label("Open the window again from the menu bar or Dock.", systemImage: "macwindow")
            Label("Notifications need macOS permission; Focus may silence them.", systemImage: "bell")
            Label("The appearance follows your Mac’s light or dark setting.", systemImage: "circle.lefthalf.filled")
            Text("Momentum 0.3.0 · Local development build").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func backup() {
        let panel = NSSavePanel()
        panel.title = "Save a Momentum backup"
        panel.nameFieldStringValue = "Momentum-backup-\(DayClock.dayKey(for: .now)).sqlite"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            Task { @MainActor in
                do {
                    let folder = destination.deletingLastPathComponent().resolvingSymlinksInPath()
                    guard folder != store.database.url.deletingLastPathComponent().resolvingSymlinksInPath() else { throw MomentumError.backupDestination }
                    let temporary = folder.appendingPathComponent(".momentum-backup-\(UUID().uuidString).sqlite")
                    defer { try? FileManager.default.removeItem(at: temporary) }
                    try store.database.backup(to: temporary)
                    if FileManager.default.fileExists(atPath: destination.path) {
                        _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
                    } else { try FileManager.default.moveItem(at: temporary, to: destination) }
                    status = "Backup saved to \(destination.lastPathComponent). Keep it somewhere safe."
                } catch { store.errorMessage = error.localizedDescription }
            }
        }
    }
}
struct MomentumMenu: View {
    @ObservedObject var workspace: Workspace
    @ObservedObject var store: MomentumStore
    @ObservedObject var focus: FocusController
    @Environment(\.openWindow) private var openWindow
    init(workspace: Workspace) {
        self.workspace = workspace; store = workspace.store; focus = workspace.focus
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) { MomentumMark(size: 20); Text("Momentum").font(.headline) }; Spacer()
                Text("\(store.tasks.filter(\.isComplete).count)/\(store.tasks.count) done").font(.caption).foregroundStyle(.secondary)
            }
            if focus.session.phase != .idle {
                Text(focus.session.taskTitle).font(.callout).lineLimit(2)
                Text(focus.session.clockText(at: focus.now)).font(.system(size: 32, weight: .light)).monospacedDigit()
                if focus.session.phase == .running { Button("Pause focus") { focus.pause() } }
                else if focus.session.phase == .paused { Button("Resume focus") { focus.resume() } }
                else { Button("Acknowledge finished session") { focus.reset() } }
            } else {
                Text("One small step is enough to begin.").foregroundStyle(.secondary)
                Button("Start 10-minute focus") { focus.start(minutes: 10, title: store.tasks.first { !$0.isComplete }?.title ?? "One small step") }
            }
            if let error = focus.errorMessage ?? store.errorMessage {
                Text(error).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }
            Divider()
            Button("Open Momentum") { show(.today) }.keyboardShortcut("0", modifiers: .command)
            Button("Night Shutdown") { show(.shutdown) }
            HStack { Spacer(); Button("Quit Momentum") { NSApp.terminate(nil) }.keyboardShortcut("q") }
        }.padding(20).frame(width: 320)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear { workspace.activate() }
    }
    private func show(_ page: WorkspacePage) {
        workspace.page = page
        openWindow(id: "dashboard")
        NSApp.activate(ignoringOtherApps: true)
    }
}

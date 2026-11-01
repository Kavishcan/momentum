import AppKit
import Combine
import MomentumCore
import SwiftUI

enum WorkspacePage: String, CaseIterable, Identifiable {
    case today = "Today", shutdown = "Night Shutdown", history = "History", settings = "Settings"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .today: return "sun.max"; case .shutdown: return "moon"; case .history: return "clock.arrow.circlepath"; case .settings: return "slider.horizontal.3" }
    }
}
@MainActor
final class Workspace: ObservableObject {
    let store: MomentumStore
    let focus: FocusController
    let reminders: ReminderCoordinator
    @Published var page: WorkspacePage = .today
    private var observations: [AnyCancellable] = []
    init(database: MomentumDatabase, client: any LocalReminderClient, ticking: Bool = true) throws {
        store = try MomentumStore(database: database)
        focus = try FocusController(database: database, ticking: ticking)
        reminders = ReminderCoordinator(database: database, client: client)
        store.refresh() // Reconciliation may have added a completed session during timer restoration.
        focus.onCompletion = { [weak self] in self?.store.refresh(); self?.reminders.notifyFocusFinished() }
        observations.append(NotificationCenter.default.publisher(for: .momentumOpenNight).receive(on: RunLoop.main).sink { [weak self] _ in
            self?.page = .shutdown
            NSApp.windows.first { $0.title == "Momentum" }?.makeKeyAndOrderFront(nil)
        })
        observations.append(focus.$now.sink { [weak self] date in
            guard let self else { return }
            if store.dayKey != DayClock.dayKey(for: date) || store.nightKey != DayClock.nightKey(for: date) { store.refresh(now: date) }
        })
        for name in [NSApplication.didBecomeActiveNotification, .NSSystemTimeZoneDidChange] {
            observations.append(NotificationCenter.default.publisher(for: name).receive(on: RunLoop.main).sink { [weak self] _ in self?.activate() })
        }
        observations.append(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification).receive(on: RunLoop.main).sink { [weak self] _ in self?.activate() })
    }
    func activate() { focus.tick(); store.refresh(); reminders.synchronize() }
}
@MainActor
final class AppRuntime: ObservableObject {
    @Published private(set) var workspace: Workspace?
    @Published private(set) var startupError: String?
    let directory = URL.applicationSupportDirectory.appendingPathComponent("Momentum", isDirectory: true)
    init() { load() }
    func load() {
        do {
            let database = try MomentumDatabase(url: directory.appendingPathComponent("momentum.sqlite"))
            try LegacyMigration.run(database: database, directory: directory)
            workspace = try Workspace(database: database, client: SystemReminderClient())
            startupError = nil
        } catch { startupError = error.localizedDescription }
    }
}
@main
struct MomentumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var runtime = AppRuntime()
    var body: some Scene {
        Window("Momentum", id: "dashboard") {
            if let workspace = runtime.workspace {
                MomentumRoot(workspace: workspace)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    Label("Your data needs attention", systemImage: "externaldrive.badge.exclamationmark").font(.title2)
                    Text(runtime.startupError ?? "Could not open local data.").textSelection(.enabled)
                    Text("Existing files have been kept. You can retry or restore a database backup while Momentum is quit.").foregroundStyle(.secondary)
                    HStack {
                        Button("Retry") { runtime.load() }
                        Button("Show data folder") { NSWorkspace.shared.open(runtime.directory) }
                        Button("Quit") { NSApp.terminate(nil) }
                    }
                }.padding(32).frame(width: 600)
            }
        }
        .defaultSize(width: 980, height: 720)
        .windowResizability(.contentMinSize)
        MenuBarExtra {
            if let workspace = runtime.workspace { MomentumMenu(workspace: workspace) }
            else { Text("Open Momentum to repair local storage."); Button("Quit") { NSApp.terminate(nil) } }
        } label: { MenuLabel(workspace: runtime.workspace) }
        .menuBarExtraStyle(.window)
    }
}
struct MenuLabel: View {
    let workspace: Workspace?
    var body: some View {
        if let focus = workspace?.focus { FocusMenuLabel(focus: focus) }
        else { Label("Momentum", systemImage: "circle.lefthalf.filled") }
    }
}
struct FocusMenuLabel: View {
    @ObservedObject var focus: FocusController
    var body: some View {
        Label(focus.session.phase == .running ? focus.session.clockText(at: focus.now) : "Momentum",
              systemImage: focus.session.phase == .finished ? "checkmark.circle" : "circle.lefthalf.filled")
            .monospacedDigit()
    }
}

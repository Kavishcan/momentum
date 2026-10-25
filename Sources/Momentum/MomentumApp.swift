import AppKit
import SwiftData
import SwiftUI
import MomentumCore

@main
struct MomentumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var focus = FocusController()
    @StateObject private var reminders = ReminderService()
    private let storage: Result<ModelContainer, Error>

    init() {
        storage = Result {
            let directory = URL.applicationSupportDirectory.appending(path: "Momentum", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let config = ModelConfiguration(
                "Momentum", url: directory.appending(path: "Momentum.store"), cloudKitDatabase: .none
            )
            return try ModelContainer(for: DailyTask.self, RoutineStep.self, configurations: config)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            switch storage {
            case .success(let container):
                MomentumRoot(container: container, focus: focus, reminders: reminders)
            case .failure(let error):
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your local store couldn’t open").font(.headline)
                    Text(error.localizedDescription).textSelection(.enabled)
                    Text("Quit and reopen Momentum. Your existing files have been kept in Application Support/Momentum.")
                    Button("Quit Momentum") { NSApp.terminate(nil) }
                }.padding(24).frame(width: 400)
            }
        } label: {
            if focus.session.phase == .running {
                Label(focus.session.clockText(at: focus.now), systemImage: "timer")
                    .monospacedDigit()
                    .accessibilityLabel("Momentum, \(focus.session.clockText(at: focus.now)) remaining")
            } else {
                Label("Momentum", systemImage: focus.session.phase == .finished ? "checkmark.circle" : "circle.lefthalf.filled")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

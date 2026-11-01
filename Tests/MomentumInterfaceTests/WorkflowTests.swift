import Foundation
import XCTest
@testable import MomentumCore
@testable import Momentum

@MainActor
final class WorkflowReminderClient: LocalReminderClient {
    var active: NightSettings?
    func authorization() async -> ReminderAuthorization { .allowed }
    func requestAuthorization() async throws -> Bool { true }
    func schedule(_ settings: NightSettings) async throws { active = settings }
    func cancel() async { active = nil }
    func sendTest() async throws {}
    func focusFinished() async {}
}
final class WorkflowTests: XCTestCase {
    @MainActor
    private func database() throws -> MomentumDatabase {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MomentumWorkflow-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return try MomentumDatabase(url: folder.appendingPathComponent("momentum.sqlite"))
    }
    @MainActor
    func testFullDayTasksFocusNightReminderBackupAndRelaunch() async throws {
        let database = try database(), client = WorkflowReminderClient()
        let app = try Workspace(database: database, client: client, ticking: false)
        XCTAssertTrue(app.store.addTask("Draft an outline"))
        XCTAssertTrue(app.store.addTask("Walk outside"))
        XCTAssertTrue(app.store.addTask("Read a page"))
        app.store.toggle(app.store.tasks[0])
        XCTAssertTrue(app.store.rename(app.store.tasks[1], to: "Walk for ten minutes"))
        XCTAssertTrue(app.store.delete(app.store.tasks[2]))
        XCTAssertTrue(app.store.addTask("Send the draft"))
        app.focus.start(minutes: 10, title: app.store.tasks[1].title)
        app.focus.pause()
        let relaunched = try Workspace(database: MomentumDatabase(url: database.url), client: client, ticking: false)
        XCTAssertEqual(relaunched.focus.session.phase, .paused)
        relaunched.focus.resume()
        relaunched.focus.tick(at: try XCTUnwrap(relaunched.focus.session.deadline).addingTimeInterval(1))
        XCTAssertEqual(relaunched.store.history.count, 1)
        XCTAssertEqual(relaunched.store.history.first?.title, "Walk for ten minutes")
        XCTAssertEqual(relaunched.store.tasks.filter(\.isComplete).count, 1, "Finishing focus must not silently complete tasks.")
        for step in relaunched.store.steps { relaunched.store.toggle(step) }
        XCTAssertTrue(relaunched.store.steps.allSatisfy(\.isComplete))
        XCTAssertTrue(relaunched.store.saveSettings(NightSettings(enabled: true, hour: 21, minute: 30)))
        relaunched.reminders.synchronize(); await relaunched.reminders.waitUntilIdle()
        XCTAssertEqual(client.active?.minute, 30)
        let backupDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: backupDirectory) }
        let backup = backupDirectory.appendingPathComponent("backup.sqlite")
        try database.backup(to: backup)
        let restored = try Workspace(database: MomentumDatabase(url: backup), client: client, ticking: false)
        XCTAssertEqual(restored.store.tasks.count, 3)
        XCTAssertEqual(restored.store.history.count, 1)
        XCTAssertTrue(restored.store.steps.allSatisfy(\.isComplete))
        XCTAssertEqual(restored.store.settings, NightSettings(enabled: true, hour: 21, minute: 30))
        XCTAssertTrue(restored.store.saveSettings(NightSettings(enabled: false)))
        restored.reminders.synchronize(); await restored.reminders.waitUntilIdle()
        XCTAssertNil(client.active)
    }
    @MainActor
    func testFailedTimerWriteDoesNotPretendToStartOrEraseRunningSession() async throws {
        let db = try database(), focus = try FocusController(database: db, ticking: false)
        try db.sql.execute("PRAGMA query_only=ON")
        focus.start(minutes: 10, title: "Unsaved")
        XCTAssertEqual(focus.session.phase, .idle)
        XCTAssertNotNil(focus.errorMessage)
        try db.sql.execute("PRAGMA query_only=OFF")
        focus.start(minutes: 25, title: "Saved")
        try db.sql.execute("PRAGMA query_only=ON")
        focus.reset()
        XCTAssertEqual(focus.session.phase, .running)
        XCTAssertEqual(try db.session().taskTitle, "Saved")
    }
    @MainActor
    func testReopenedWorkspaceImmediatelyShowsRecoveredCompletion() async throws {
        let db = try database(), start = Date.now.addingTimeInterval(-1_000)
        var session = FocusSession(); session.start(minutes: 10, taskTitle: "Recovered session", now: start)
        try db.saveSession(session)
        let app = try Workspace(database: db, client: WorkflowReminderClient(), ticking: false)
        XCTAssertEqual(app.focus.session.phase, .finished)
        XCTAssertEqual(app.store.history.first?.title, "Recovered session")
    }
}

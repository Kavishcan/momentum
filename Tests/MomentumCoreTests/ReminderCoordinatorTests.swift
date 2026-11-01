import XCTest
@testable import MomentumCore

@MainActor
final class FakeReminderClient: LocalReminderClient {
    var permission: ReminderAuthorization = .allowed
    var requests = 0
    var scheduled: [NightSettings] = []
    var active: NightSettings?
    var cancelled = 0
    var shouldFail = false
    var delay = false
    var testCount = 0
    var completionCount = 0
    func authorization() async -> ReminderAuthorization { permission }
    func requestAuthorization() async throws -> Bool { requests += 1; return permission == .allowed }
    func schedule(_ settings: NightSettings) async throws {
        if delay { try await Task.sleep(for: .milliseconds(30)) }
        if shouldFail { throw MomentumError.database("Scheduling unavailable") }
        scheduled.append(settings); active = settings
    }
    func cancel() async { cancelled += 1; active = nil }
    func sendTest() async throws { testCount += 1 }
    func focusFinished() async { completionCount += 1 }
}
final class ReminderCoordinatorTests: XCTestCase {
    @MainActor
    private func database() throws -> MomentumDatabase {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ReminderTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return try MomentumDatabase(url: folder.appendingPathComponent("db.sqlite"))
    }
    @MainActor
    func testEnabledScheduleIsRestoredWithoutPermissionPrompt() async throws {
        let db = try database(), client = FakeReminderClient()
        let settings = NightSettings(enabled: true, hour: 21, minute: 15)
        try db.saveSettings(settings)
        let coordinator = ReminderCoordinator(database: db, client: client)
        coordinator.synchronize(); await coordinator.waitUntilIdle()
        XCTAssertEqual(client.active, settings)
        XCTAssertEqual(client.requests, 0)
        XCTAssertFalse(coordinator.busy)
    }
    @MainActor
    func testDeniedPermissionNeverReportsScheduledAndDisableCancels() async throws {
        let db = try database(), client = FakeReminderClient()
        client.permission = .denied
        try db.saveSettings(NightSettings(enabled: true))
        let coordinator = ReminderCoordinator(database: db, client: client)
        coordinator.synchronize(); await coordinator.waitUntilIdle()
        XCTAssertTrue(client.scheduled.isEmpty)
        XCTAssertTrue(coordinator.status.contains("Permission"))
        try db.saveSettings(NightSettings(enabled: false))
        coordinator.synchronize(); await coordinator.waitUntilIdle()
        XCTAssertNil(client.active)
        XCTAssertEqual(coordinator.status, "Reminders are off.")
    }
    @MainActor
    func testRapidEditsConvergeOnNewestTimeAndOffWins() async throws {
        let db = try database(), client = FakeReminderClient(); client.delay = true
        let coordinator = ReminderCoordinator(database: db, client: client)
        for minute in 0..<6 {
            try db.saveSettings(NightSettings(enabled: true, hour: 22, minute: minute))
            coordinator.synchronize()
            await Task.yield()
        }
        await coordinator.waitUntilIdle()
        XCTAssertEqual(client.active?.minute, 5)
        try db.saveSettings(NightSettings(enabled: false))
        coordinator.synchronize(); await coordinator.waitUntilIdle()
        XCTAssertNil(client.active)
    }
    @MainActor
    func testSchedulingFailureSurfacesAndRetryRecovers() async throws {
        let db = try database(), client = FakeReminderClient(); client.shouldFail = true
        try db.saveSettings(NightSettings(enabled: true))
        let coordinator = ReminderCoordinator(database: db, client: client)
        coordinator.synchronize(); await coordinator.waitUntilIdle()
        XCTAssertTrue(coordinator.status.contains("not scheduled"))
        client.shouldFail = false
        coordinator.synchronize(); await coordinator.waitUntilIdle()
        XCTAssertNotNil(client.active)
        try await coordinator.test()
        XCTAssertEqual(client.testCount, 1)
        client.permission = .denied
        do { try await coordinator.test(); XCTFail("Denied test must fail") } catch {}
        XCTAssertEqual(client.testCount, 1)
    }
}

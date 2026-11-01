import Foundation
import SwiftData
import XCTest
@testable import MomentumCore

final class MomentumStoreTests: XCTestCase {
    @MainActor
    private func makeDatabase() throws -> MomentumDatabase {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MomentumTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try MomentumDatabase(url: root.appendingPathComponent("momentum.sqlite"))
    }
    @MainActor
    func testThreeTasksIncludingCompletedAndSQLInjectionTitle() async throws {
        let db = try makeDatabase(), day = "2026-11-01"
        try db.addTask("One", day: day)
        try db.addTask("Two", day: day)
        let literal = "'); DROP TABLE tasks; --"
        try db.addTask(literal, day: day)
        let task = try XCTUnwrap(db.tasks(on: day).first)
        try db.setTaskComplete(task.id, true)
        XCTAssertThrowsError(try db.addTask("Four", day: day))
        XCTAssertEqual(try db.tasks(on: day).count, 3)
        XCTAssertTrue(try db.tasks(on: day).contains { $0.title == literal })
        try db.deleteTask(task.id)
        try db.addTask("Replacement", day: day)
        XCTAssertEqual(try db.tasks(on: day).count, 3)
    }
    @MainActor
    func testSQLiteTriggerProtectsLimitAcrossConnections() async throws {
        let db = try makeDatabase(), day = "2026-11-01"
        let other = try MomentumDatabase(url: db.url)
        for title in ["One", "Two", "Three"] { try db.addTask(title, day: day) }
        XCTAssertThrowsError(try other.addTask("Four", day: day))
        XCTAssertThrowsError(try other.insertTask(MomentumTask(title: "Bypass", dayKey: day)))
        XCTAssertEqual(try other.tasks(on: day).count, 3)
    }
    @MainActor
    func testInvalidInputAndMissingRecordNeverSilentlySave() async throws {
        let db = try makeDatabase()
        XCTAssertThrowsError(try db.addTask("  ", day: "2026-11-01"))
        XCTAssertThrowsError(try db.addTask(String(repeating: "A", count: 201), day: "2026-11-01"))
        XCTAssertThrowsError(try db.renameTask(UUID(), to: "Missing"))
        XCTAssertThrowsError(try db.saveSettings(NightSettings(hour: 25)))
        XCTAssertEqual(try db.settings(), NightSettings())
    }
    @MainActor
    func testTaskEditCompletionSettingsAndRoutinePersistAcrossReopen() async throws {
        let db = try makeDatabase(), day = "2026-11-01"
        try db.addTask("  Draft  ", day: day)
        let task = try XCTUnwrap(db.tasks(on: day).first)
        try db.renameTask(task.id, to: "Write the introduction")
        try db.setTaskComplete(task.id, true)
        let step = try XCTUnwrap(db.steps(on: day).first)
        try db.renameStep(step.id, to: "Read one page")
        try db.setStepComplete(step.id, night: day, true)
        let settings = NightSettings(enabled: true, hour: 21, minute: 45)
        try db.saveSettings(settings)
        let reopened = try MomentumDatabase(url: db.url)
        XCTAssertEqual(try reopened.tasks(on: day).first?.title, "Write the introduction")
        XCTAssertEqual(try reopened.tasks(on: day).first?.isComplete, true)
        XCTAssertEqual(try reopened.settings(), settings)
        XCTAssertTrue(try reopened.steps(on: day).contains { $0.id == step.id && $0.isComplete && $0.title == "Read one page" })
        XCTAssertTrue(try reopened.steps(on: "2026-11-02").allSatisfy { !$0.isComplete })
        XCTAssertEqual(try reopened.integrityCheck(), "ok")
    }
    @MainActor
    func testRoutineHistoryAndDeletedDefaultsStayDeleted() async throws {
        let db = try makeDatabase(), night = "2026-11-01"
        let step = try XCTUnwrap(db.steps(on: night).first)
        try db.setStepComplete(step.id, night: night, true)
        try db.setStepComplete(step.id, night: "2026-11-02", true)
        try db.setStepComplete(step.id, night: "2026-11-02", false)
        XCTAssertEqual(try db.steps(on: night).first?.isComplete, true)
        for item in try db.steps(on: night) { try db.deleteStep(item.id) }
        let reopened = try MomentumDatabase(url: db.url)
        XCTAssertTrue(try reopened.steps(on: night).isEmpty)
        XCTAssertTrue(try db.sql.rows("SELECT * FROM routine_checks").isEmpty)
        for n in 0..<10 { try db.addStep("Step \(n)") }
        XCTAssertThrowsError(try db.addStep("Too many"))
    }
    @MainActor
    func testStoreRetainsInputStateAfterDatabaseWriteFailure() async throws {
        let db = try makeDatabase(), store = try MomentumStore(database: db)
        XCTAssertTrue(store.addTask("Keep this"))
        try db.sql.execute("PRAGMA query_only=ON")
        XCTAssertFalse(store.addTask("Must not appear"))
        XCTAssertEqual(store.tasks.map(\.title), ["Keep this"])
        XCTAssertNotNil(store.errorMessage)
        try db.sql.execute("PRAGMA query_only=OFF")
        store.errorMessage = nil
        XCTAssertTrue(store.addTask("Retry"))
        XCTAssertEqual(store.tasks.count, 2)
    }
    @MainActor
    func testDailyRolloverPreservesHistory() async throws {
        let db = try makeDatabase()
        let now = Date.now, next = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let store = try MomentumStore(database: db, now: now)
        XCTAssertTrue(store.addTask("Today", now: now))
        store.refresh(now: next)
        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertTrue(store.addTask("Tomorrow", now: next))
        XCTAssertEqual(try db.days().count, 2)
        store.refresh(now: now)
        XCTAssertEqual(store.tasks.map(\.title), ["Today"])
    }
    @MainActor
    func testBackupContainsWALTasksSettingsChecksAndActiveTimer() async throws {
        let db = try makeDatabase(), day = "2026-11-01"
        try db.addTask("Not checkpointed", day: day)
        try db.saveSettings(NightSettings(enabled: true, hour: 23, minute: 12))
        let step = try XCTUnwrap(db.steps(on: day).first)
        try db.setStepComplete(step.id, night: day, true)
        var timer = FocusSession(); timer.start(minutes: 25, taskTitle: "Draft")
        try db.saveSession(timer)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MomentumBackup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("backup.sqlite")
        try db.backup(to: target)
        let restored = try MomentumDatabase(url: target)
        XCTAssertEqual(try restored.tasks(on: day).map(\.title), ["Not checkpointed"])
        XCTAssertEqual(try restored.settings().minute, 12)
        XCTAssertTrue(try restored.steps(on: day).contains { $0.id == step.id && $0.isComplete })
        XCTAssertEqual(try restored.session(), timer)
        XCTAssertEqual(try restored.integrityCheck(), "ok")
        XCTAssertThrowsError(try db.backup(to: db.url))
        XCTAssertThrowsError(try db.backup(to: target))
    }
    @MainActor
    func testFinishedSessionHistoryIsIdempotentAndSurvivesReopen() async throws {
        let db = try makeDatabase(), now = Date.now
        var session = FocusSession(); session.start(minutes: 10, taskTitle: "Finish draft", now: now)
        XCTAssertTrue(session.reconcile(now: now.addingTimeInterval(700)))
        try db.saveSession(session); try db.saveSession(session)
        let reopened = try MomentumDatabase(url: db.url)
        XCTAssertEqual(try reopened.focusHistory().count, 1)
        XCTAssertEqual(try reopened.focusHistory().first?.title, "Finish draft")
        try reopened.saveSession(FocusSession())
        XCTAssertEqual(try reopened.focusHistory().count, 1)
    }
    @MainActor
    func testMigrationTransactionRollsBackAndImportIsIdempotent() async throws {
        let db = try makeDatabase()
        var invalid = LegacyData()
        invalid.tasks = [MomentumTask(title: "Valid", dayKey: "2026-11-01"), MomentumTask(title: "", dayKey: "2026-11-01")]
        XCTAssertThrowsError(try db.importLegacy(invalid))
        XCTAssertTrue(try db.tasks(on: "2026-11-01").isEmpty)
        XCTAssertEqual(try db.steps(on: "2026-11-01").count, 3)
        XCTAssertFalse(try db.legacyImportComplete)
        var valid = LegacyData(); valid.tasks = [MomentumTask(title: "Migrated", dayKey: "2026-11-01")]
        try db.importLegacy(valid); try db.importLegacy(valid)
        XCTAssertEqual(try db.tasks(on: "2026-11-01").count, 1)
        XCTAssertTrue(try db.steps(on: "2026-11-01").isEmpty)
    }
    @MainActor
    func testActualSwiftDataMigrationPreservesOriginalAndOldTimer() async throws {
        let db = try makeDatabase(), directory = db.url.deletingLastPathComponent()
        let config = ModelConfiguration("Momentum", url: directory.appendingPathComponent("Momentum.store"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: DailyTask.self, RoutineStep.self, configurations: config)
        let context = ModelContext(container)
        let legacy = DailyTask(title: "Old task", dayKey: "2026-10-25")
        let step = RoutineStep(title: "Old routine", position: 0); step.completedNightKey = "2026-10-25"
        context.insert(legacy); context.insert(step); try context.save()
        let suite = "MigrationTest.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "night.enabled"); defaults.set(21, forKey: "night.hour")
        var timer = FocusSession(); timer.start(minutes: 25, taskTitle: "Old focus")
        var oldJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(timer)) as? [String: Any])
        oldJSON.removeValue(forKey: "id")
        defaults.set(try JSONSerialization.data(withJSONObject: oldJSON), forKey: "focus.session.v1")
        try LegacyMigration.run(database: db, directory: directory, defaults: defaults)
        XCTAssertEqual(try db.tasks(on: "2026-10-25").first?.id, legacy.id)
        XCTAssertEqual(try db.steps(on: "2026-10-25").first?.isComplete, true)
        XCTAssertEqual(try db.settings().hour, 21)
        XCTAssertEqual(try db.session().taskTitle, "Old focus")
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailyTask>()).count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("MigrationBackups").path))
    }
    @MainActor
    func testNewerSchemaIsRefusedInsteadOfOverwritten() async throws {
        let db = try makeDatabase()
        try db.sql.execute("PRAGMA user_version=99")
        XCTAssertThrowsError(try MomentumDatabase(url: db.url))
    }
    @MainActor
    func testExistingUserStoreCanMigrateFromAnIsolatedSnapshot() async throws {
        guard let path = ProcessInfo.processInfo.environment["MOMENTUM_LEGACY_TEST_SOURCE"] else {
            throw XCTSkip("Set a local legacy store path to verify an isolated snapshot; CI uses the synthetic migration fixture.")
        }
        let db = try makeDatabase(), directory = db.url.deletingLastPathComponent()
        let source = try SQLiteConnection(url: URL(fileURLWithPath: path), readOnly: true)
        try source.backup(to: directory.appendingPathComponent("Momentum.store"))
        let oldTaskCount = Int(try source.rows("SELECT count(*) FROM ZDAILYTASK")[0][0])!
        let oldStepCount = Int(try source.rows("SELECT count(*) FROM ZROUTINESTEP")[0][0])!
        let defaults = UserDefaults(suiteName: "com.kavishcan.momentum")!
        try LegacyMigration.run(database: db, directory: directory, defaults: defaults)
        let imported = try db.days().reduce(0) { total, day in total + (try db.tasks(on: day).count) }
        XCTAssertEqual(imported, oldTaskCount)
        XCTAssertEqual(try db.steps(on: DayClock.nightKey(for: .now)).count, oldStepCount)
        XCTAssertEqual(try db.integrityCheck(), "ok")
        XCTAssertTrue(try db.legacyImportComplete)
    }

}

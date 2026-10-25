import SwiftData
import XCTest
@testable import MomentumCore

final class MomentumStoreTests: XCTestCase {
    @MainActor
    private func container(url: URL? = nil) throws -> ModelContainer {
        let config: ModelConfiguration
        if let url { config = ModelConfiguration("Test", url: url, cloudKitDatabase: .none) }
        else { config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none) }
        return try ModelContainer(for: DailyTask.self, RoutineStep.self, configurations: config)
    }

    private func isolatedDefaults() -> (UserDefaults, String) {
        let name = "MomentumTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    @MainActor
    func testDailyThreeLimitIncludesCompletedAndIgnoresBlankInput() async throws {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let store = MomentumStore(container: try container(), defaults: defaults)
        store.addTask("  ")
        XCTAssertTrue(store.tasks.isEmpty)
        ["One", "Two", "Three"].forEach { store.addTask($0) }
        store.toggle(store.tasks[0])
        store.addTask("Four")
        XCTAssertEqual(store.tasks.count, 3)
        XCTAssertNotNil(store.errorMessage)
        store.errorMessage = nil
        store.delete(store.tasks[1])
        store.addTask("Replacement")
        XCTAssertEqual(store.tasks.count, 3)
        XCTAssertTrue(store.tasks.contains { $0.title == "Replacement" })
    }

    @MainActor
    func testDailyRolloverDoesNotLosePreviousTasks() async throws {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let database = try container()
        let store = MomentumStore(container: database, defaults: defaults)
        let now = Date.now
        store.addTask("Today", now: now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        store.refresh(now: tomorrow)
        XCTAssertTrue(store.tasks.isEmpty)
        store.addTask("Tomorrow", now: tomorrow)
        store.refresh(now: now)
        XCTAssertEqual(store.tasks.map(\.title), ["Today"])
    }

    @MainActor
    func testRoutineCompletionResetsAndEmptyRoutineStaysEmpty() async throws {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let database = try container()
        let store = MomentumStore(container: database, defaults: defaults)
        XCTAssertEqual(store.steps.count, 3)
        let now = Date.now
        let step = store.steps[0]
        store.rename(step, to: "  Charge phone outside bedroom  ")
        XCTAssertEqual(step.title, "Charge phone outside bedroom")
        store.toggle(step, now: now)
        XCTAssertEqual(step.completedNightKey, store.nightKey)
        store.refresh(now: Calendar.current.date(byAdding: .day, value: 1, to: now)!)
        XCTAssertNotEqual(step.completedNightKey, store.nightKey)
        for item in store.steps { store.delete(item) }
        let reopened = MomentumStore(container: database, defaults: defaults)
        XCTAssertTrue(reopened.steps.isEmpty)
        reopened.addStep("Read a page")
        XCTAssertEqual(reopened.steps.map(\.title), ["Read a page"])
    }

    @MainActor
    func testTasksAndChecklistSurviveDiskStoreReopen() async throws {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Test.store")
        do {
            let store = MomentumStore(container: try container(url: url), defaults: defaults)
            store.addTask("  Write a paragraph  ")
            store.toggle(store.tasks[0])
            store.toggle(store.steps[0])
            XCTAssertNil(store.errorMessage)
        }
        let reopened = MomentumStore(container: try container(url: url), defaults: defaults)
        XCTAssertEqual(reopened.tasks.map(\.title), ["Write a paragraph"])
        XCTAssertEqual(reopened.tasks.first?.isComplete, true)
        XCTAssertEqual(reopened.steps.first?.completedNightKey, reopened.nightKey)
        XCTAssertNil(reopened.errorMessage)
    }
}

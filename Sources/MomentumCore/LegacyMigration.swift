import Foundation
import SwiftData

public struct LegacyData {
    public var tasks: [MomentumTask] = []
    public var steps: [ShutdownStep] = []
    public var completedNights: [UUID: String] = [:]
    public var settings = NightSettings()
    public var session = FocusSession()
    public init() {}
}

extension MomentumDatabase {
    public var legacyImportComplete: Bool { get throws { try metadata("legacy_import") != nil } }
    public func importLegacy(_ data: LegacyData) throws {
        guard try !legacyImportComplete else { return }
        // Migration either commits all records/preferences/timer together or leaves the new DB unchanged.
        try sql.transaction {
            guard try !legacyImportComplete else { return }
            try sql.execute("DELETE FROM routine_steps")
            for task in data.tasks { try insertTask(task) }
            for step in data.steps {
                try insertStep(step)
                if let night = data.completedNights[step.id] { try setStepComplete(step.id, night: night, true) }
            }
            try saveSettings(data.settings)
            try writeSession(data.session)
            try setMetadata("legacy_import", "done")
        }
    }
    public func finishWithoutLegacyImport() throws { try setMetadata("legacy_import", "not_needed") }
}

@MainActor
public enum LegacyMigration {
    public static func run(database: MomentumDatabase, directory: URL, defaults: UserDefaults = .standard) throws {
        guard try !database.legacyImportComplete else { return }
        let oldURL = directory.appendingPathComponent("Momentum.store")
        guard FileManager.default.fileExists(atPath: oldURL.path) else {
            try database.finishWithoutLegacyImport(); return
        }
        do {
            // Use a consistent SQLite snapshot so the old store and its WAL remain untouched.
            let backupFolder = directory.appendingPathComponent("MigrationBackups", isDirectory: true)
            try FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
            let backupURL = backupFolder.appendingPathComponent("Momentum-legacy-\(UUID().uuidString).store")
            let source = try SQLiteConnection(url: oldURL, readOnly: true)
            try source.backup(to: backupURL)
            let workingDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("MomentumMigration-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: workingDirectory) }
            let workingURL = workingDirectory.appendingPathComponent("Momentum.store")
            try FileManager.default.copyItem(at: backupURL, to: workingURL)
            let data = try readLegacy(at: workingURL, defaults: defaults)
            try database.importLegacy(data)
        } catch { throw MomentumError.migration(error.localizedDescription) }
    }
    private static func readLegacy(at url: URL, defaults: UserDefaults) throws -> LegacyData {
        // Core Data may need to create WAL/SHM metadata. Only this disposable snapshot is writable.
        let config = ModelConfiguration("Momentum", url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: DailyTask.self, RoutineStep.self, configurations: config)
        let context = ModelContext(container)
        var data = LegacyData()
        data.tasks = try context.fetch(FetchDescriptor<DailyTask>()).map {
            MomentumTask(id: $0.id, title: $0.title, dayKey: $0.dayKey, createdAt: $0.createdAt, isComplete: $0.isComplete)
        }
        let steps = try context.fetch(FetchDescriptor<RoutineStep>())
        data.steps = steps.map { ShutdownStep(id: $0.id, title: $0.title, position: $0.position) }
        for step in steps { if let key = step.completedNightKey { data.completedNights[step.id] = key } }
        data.settings = NightSettings(enabled: defaults.bool(forKey: "night.enabled"),
                                      hour: defaults.object(forKey: "night.hour") as? Int ?? 22,
                                      minute: defaults.object(forKey: "night.minute") as? Int ?? 0)
        if let oldSession = defaults.data(forKey: "focus.session.v1") {
            data.session = try JSONDecoder().decode(FocusSession.self, from: oldSession)
        }
        return data
    }
}

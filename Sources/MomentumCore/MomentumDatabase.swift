import Foundation

@MainActor
public final class MomentumDatabase {
    public let url: URL
    let sql: SQLiteConnection
    public init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        sql = try SQLiteConnection(url: url)
        let version = Int(try sql.rows("PRAGMA user_version").first?.first ?? "0") ?? 0
        guard version <= 1 else { throw MomentumError.newerDatabase }
        if version == 0 { try createSchema() }
        try seed()
        guard try integrityCheck() == "ok" else { throw MomentumError.database("The integrity check failed. Restore a known-good backup while Momentum is quit.") }
    }
    private func createSchema() throws {
        try sql.transaction {
            guard (Int(try sql.rows("PRAGMA user_version")[0][0]) ?? 0) == 0 else { return }
            for statement in [
                "CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)",
                "CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 200), day_key TEXT NOT NULL, created_at REAL NOT NULL, completed INTEGER NOT NULL CHECK(completed IN (0,1)))",
                "CREATE INDEX tasks_by_day ON tasks(day_key,created_at)",
                "CREATE TRIGGER daily_three_limit BEFORE INSERT ON tasks WHEN (SELECT count(*) FROM tasks WHERE day_key=NEW.day_key)>=3 BEGIN SELECT RAISE(ABORT,'daily_three_limit'); END",
                "CREATE TABLE routine_steps (id TEXT PRIMARY KEY, title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 200), position INTEGER NOT NULL)",
                "CREATE TABLE routine_checks (step_id TEXT NOT NULL REFERENCES routine_steps(id) ON DELETE CASCADE, night_key TEXT NOT NULL, PRIMARY KEY(step_id,night_key))",
                "CREATE TABLE night_settings (id INTEGER PRIMARY KEY CHECK(id=1), enabled INTEGER NOT NULL CHECK(enabled IN(0,1)), hour INTEGER NOT NULL CHECK(hour BETWEEN 0 AND 23), minute INTEGER NOT NULL CHECK(minute BETWEEN 0 AND 59))",
                "CREATE TABLE active_focus (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL)",
                "CREATE TABLE focus_history (id TEXT PRIMARY KEY, title TEXT NOT NULL, duration REAL NOT NULL CHECK(duration>0), finished_at REAL NOT NULL)",
                "PRAGMA user_version=1"
            ] { try sql.execute(statement) }
        }
    }
    private func seed() throws {
        try sql.transaction {
            guard try metadata("seeded") == nil else { return }
            try sql.execute("INSERT INTO night_settings VALUES(1,0,22,0)")
            try writeSession(FocusSession())
            for (index, title) in ["Park your phone away from bed", "Write tomorrow’s first small step", "Close the laptop and wind down"].enumerated() {
                try insertStep(ShutdownStep(title: title, position: index))
            }
            try setMetadata("seeded", "1")
        }
    }
    func metadata(_ key: String) throws -> String? {
        try sql.rows("SELECT value FROM metadata WHERE key=?", [.text(key)]).first?.first
    }
    func setMetadata(_ key: String, _ value: String) throws {
        try sql.execute("INSERT INTO metadata(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", [.text(key),.text(value)])
    }
    private func clean(_ title: String) throws -> String {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 200, !value.contains("\0") else { throw MomentumError.invalidTitle }
        return value
    }
    public func tasks(on day: String) throws -> [MomentumTask] {
        try sql.rows("SELECT id,title,day_key,created_at,completed FROM tasks WHERE day_key=? ORDER BY created_at,id", [.text(day)]).map { row in
            guard let id = UUID(uuidString: row[0]), let timestamp = Double(row[3]) else { throw MomentumError.database("Invalid task record.") }
            return MomentumTask(id: id, title: row[1], dayKey: row[2], createdAt: Date(timeIntervalSince1970: timestamp), isComplete: row[4] == "1")
        }
    }
    public func days() throws -> [String] { try sql.rows("SELECT DISTINCT day_key FROM tasks ORDER BY day_key DESC").map { $0[0] } }
    public func addTask(_ title: String, day: String, now: Date = .now) throws {
        let value = try clean(title)
        try sql.transaction {
            guard try tasks(on: day).count < 3 else { throw MomentumError.taskLimit }
            try insertTask(MomentumTask(title: value, dayKey: day, createdAt: now))
        }
    }
    func insertTask(_ task: MomentumTask) throws {
        try sql.execute("INSERT INTO tasks VALUES(?,?,?,?,?)", [.text(task.id.uuidString),.text(try clean(task.title)),.text(task.dayKey),.number(task.createdAt.timeIntervalSince1970),.integer(task.isComplete ? 1 : 0)])
    }
    public func renameTask(_ id: UUID, to title: String) throws {
        try sql.execute("UPDATE tasks SET title=? WHERE id=?", [.text(try clean(title)),.text(id.uuidString)])
        guard sql.changedRows == 1 else { throw MomentumError.missingRecord }
    }
    public func setTaskComplete(_ id: UUID, _ completed: Bool) throws {
        try sql.execute("UPDATE tasks SET completed=? WHERE id=?", [.integer(completed ? 1 : 0),.text(id.uuidString)])
        guard sql.changedRows == 1 else { throw MomentumError.missingRecord }
    }
    public func deleteTask(_ id: UUID) throws { try sql.execute("DELETE FROM tasks WHERE id=?", [.text(id.uuidString)]) }
    public func steps(on night: String) throws -> [ShutdownStep] {
        try sql.rows("SELECT s.id,s.title,s.position,EXISTS(SELECT 1 FROM routine_checks c WHERE c.step_id=s.id AND c.night_key=?) FROM routine_steps s ORDER BY s.position,s.id", [.text(night)]).map { row in
            guard let id = UUID(uuidString: row[0]), let position = Int(row[2]) else { throw MomentumError.database("Invalid routine record.") }
            return ShutdownStep(id: id, title: row[1], position: position, isComplete: row[3] == "1")
        }
    }
    func insertStep(_ step: ShutdownStep) throws {
        try sql.execute("INSERT INTO routine_steps VALUES(?,?,?)", [.text(step.id.uuidString),.text(try clean(step.title)),.integer(step.position)])
    }
    public func addStep(_ title: String) throws {
        let value = try clean(title)
        try sql.transaction {
            let count = Int(try sql.rows("SELECT count(*) FROM routine_steps")[0][0]) ?? 0
            guard count < 10 else { throw MomentumError.stepLimit }
            let next = (Int(try sql.rows("SELECT coalesce(max(position),-1) FROM routine_steps")[0][0]) ?? -1) + 1
            try insertStep(ShutdownStep(title: value, position: next))
        }
    }
    public func renameStep(_ id: UUID, to title: String) throws {
        try sql.execute("UPDATE routine_steps SET title=? WHERE id=?", [.text(try clean(title)),.text(id.uuidString)])
        guard sql.changedRows == 1 else { throw MomentumError.missingRecord }
    }
    public func setStepComplete(_ id: UUID, night: String, _ completed: Bool) throws {
        if completed { try sql.execute("INSERT OR IGNORE INTO routine_checks VALUES(?,?)", [.text(id.uuidString),.text(night)]) }
        else { try sql.execute("DELETE FROM routine_checks WHERE step_id=? AND night_key=?", [.text(id.uuidString),.text(night)]) }
    }
    public func deleteStep(_ id: UUID) throws { try sql.execute("DELETE FROM routine_steps WHERE id=?", [.text(id.uuidString)]) }
    public func settings() throws -> NightSettings {
        let rows = try sql.rows("SELECT enabled,hour,minute FROM night_settings WHERE id=1")
        guard let row = rows.first, let hour = Int(row[1]), let minute = Int(row[2]) else { throw MomentumError.invalidSettings }
        return NightSettings(enabled: row[0] == "1", hour: hour, minute: minute)
    }
    public func saveSettings(_ settings: NightSettings) throws {
        guard settings.isValid else { throw MomentumError.invalidSettings }
        try sql.execute("UPDATE night_settings SET enabled=?,hour=?,minute=? WHERE id=1", [.integer(settings.enabled ? 1 : 0),.integer(settings.hour),.integer(settings.minute)])
    }
    public func session() throws -> FocusSession {
        guard let raw = try sql.rows("SELECT payload FROM active_focus WHERE id=1").first?.first,
              let data = raw.data(using: .utf8), let session = try? JSONDecoder().decode(FocusSession.self, from: data), session.isValid else { throw MomentumError.invalidTimer }
        return session
    }
    func writeSession(_ session: FocusSession) throws {
        guard session.isValid else { throw MomentumError.invalidTimer }
        let payload = String(decoding: try JSONEncoder().encode(session), as: UTF8.self)
        try sql.execute("INSERT INTO active_focus VALUES(1,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload", [.text(payload)])
    }
    public func saveSession(_ session: FocusSession, now: Date = .now) throws {
        try sql.transaction {
            try writeSession(session)
            if session.phase == .finished {
                try sql.execute("INSERT OR IGNORE INTO focus_history VALUES(?,?,?,?)", [.text(session.id.uuidString),.text(session.taskTitle),.number(session.duration),.number((session.finishedAt ?? now).timeIntervalSince1970)])
            }
        }
    }
    public func focusHistory() throws -> [FocusRecord] {
        try sql.rows("SELECT id,title,duration,finished_at FROM focus_history ORDER BY finished_at DESC LIMIT 100").map { row in
            guard let id = UUID(uuidString: row[0]), let duration = Double(row[2]), let timestamp = Double(row[3]) else { throw MomentumError.database("Invalid focus record.") }
            return FocusRecord(id: id, title: row[1], duration: duration, finishedAt: Date(timeIntervalSince1970: timestamp))
        }
    }
    public func integrityCheck() throws -> String { try sql.rows("PRAGMA quick_check").map { $0[0] }.joined(separator: "\n") }
    public func backup(to destination: URL) throws {
        guard destination.deletingLastPathComponent().standardizedFileURL != url.deletingLastPathComponent().standardizedFileURL else { throw MomentumError.backupDestination }
        try sql.backup(to: destination)
    }
}

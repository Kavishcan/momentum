import CSQLite
import Foundation

/// All app access is serialized on the main actor. FULLMUTEX also protects SQLite internals.
@MainActor
final class SQLiteConnection {
    private(set) var handle: OpaquePointer?
    let url: URL
    init(url: URL, readOnly: Bool = false) throws {
        self.url = url
        let flags = (readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE) | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(url.path, &handle, flags, nil)
        guard result == SQLITE_OK else {
            let detail = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open the file."
            sqlite3_close(handle); handle = nil
            throw MomentumError.database(detail)
        }
        sqlite3_busy_timeout(handle, 1_500)
        if !readOnly {
            try execute("PRAGMA foreign_keys=ON")
            try execute("PRAGMA journal_mode=WAL")
            try execute("PRAGMA synchronous=FULL")
        }
    }
    deinit { sqlite3_close(handle) }

    enum Value { case text(String), number(Double), integer(Int), null }
    func statement(_ sql: String, _ bindings: [Value] = []) throws -> OpaquePointer {
        var pointer: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &pointer, nil) == SQLITE_OK, let pointer else { throw failure() }
        do {
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            for (offset, value) in bindings.enumerated() {
                let index = Int32(offset + 1)
                let code: Int32
                switch value {
                case .text(let string): code = sqlite3_bind_text(pointer, index, string, -1, transient)
                case .number(let number): code = sqlite3_bind_double(pointer, index, number)
                case .integer(let integer): code = sqlite3_bind_int64(pointer, index, Int64(integer))
                case .null: code = sqlite3_bind_null(pointer, index)
                }
                guard code == SQLITE_OK else { throw failure() }
            }
            return pointer
        } catch { sqlite3_finalize(pointer); throw error }
    }
    func execute(_ sql: String, _ bindings: [Value] = []) throws {
        let pointer = try statement(sql, bindings)
        defer { sqlite3_finalize(pointer) }
        var result = sqlite3_step(pointer)
        // PRAGMA statements may return rows before DONE.
        while result == SQLITE_ROW { result = sqlite3_step(pointer) }
        guard result == SQLITE_DONE else { throw failure() }
    }
    func rows(_ sql: String, _ bindings: [Value] = []) throws -> [[String]] {
        let pointer = try statement(sql, bindings)
        defer { sqlite3_finalize(pointer) }
        var output: [[String]] = []
        var result = sqlite3_step(pointer)
        while result == SQLITE_ROW {
            output.append((0..<sqlite3_column_count(pointer)).map { index in
                if sqlite3_column_type(pointer, index) == SQLITE_FLOAT { return String(sqlite3_column_double(pointer, index)) }
                return sqlite3_column_text(pointer, index).map { String(cString: $0) } ?? ""
            })
            result = sqlite3_step(pointer)
        }
        guard result == SQLITE_DONE else { throw failure() }
        return output
    }
    func transaction<T>(_ operation: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do {
            let result = try operation()
            try execute("COMMIT")
            return result
        } catch { try? execute("ROLLBACK"); throw error }
    }
    var changedRows: Int { Int(sqlite3_changes(handle)) }
    func failure() -> MomentumError { .database(String(cString: sqlite3_errmsg(handle))) }

    /// SQLite's backup API includes committed WAL pages, unlike copying only the main file.
    func backup(to destination: URL) throws {
        guard destination.standardizedFileURL != url.standardizedFileURL,
              !FileManager.default.fileExists(atPath: destination.path) else { throw MomentumError.backupDestination }
        var target: OpaquePointer?
        guard sqlite3_open(destination.path, &target) == SQLITE_OK else {
            sqlite3_close(target); throw MomentumError.database("Could not create the backup file.")
        }
        defer { sqlite3_close(target) }
        guard let backup = sqlite3_backup_init(target, "main", handle, "main") else {
            throw MomentumError.database("Could not start the database backup.")
        }
        let result = sqlite3_backup_step(backup, -1)
        let finished = sqlite3_backup_finish(backup)
        guard result == SQLITE_DONE, finished == SQLITE_OK else {
            try? FileManager.default.removeItem(at: destination)
            let detail = String(cString: sqlite3_errmsg(target))
            throw MomentumError.database("The backup did not complete (SQLite \(result)/\(finished)): \(detail)")
        }
        // A standalone snapshot must not require missing WAL/SHM files on its next read-only open.
        guard sqlite3_exec(target, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK else {
            try? FileManager.default.removeItem(at: destination)
            throw MomentumError.database("Could not finalize the standalone backup: \(String(cString: sqlite3_errmsg(target)))")
        }
    }
}

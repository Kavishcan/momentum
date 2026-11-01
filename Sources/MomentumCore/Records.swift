import Foundation

public struct MomentumTask: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public let dayKey: String
    public let createdAt: Date
    public var isComplete: Bool
    public init(id: UUID = UUID(), title: String, dayKey: String, createdAt: Date = .now, isComplete: Bool = false) {
        self.id = id; self.title = title; self.dayKey = dayKey; self.createdAt = createdAt; self.isComplete = isComplete
    }
}

public struct ShutdownStep: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public let position: Int
    public var isComplete: Bool
    public init(id: UUID = UUID(), title: String, position: Int, isComplete: Bool = false) {
        self.id = id; self.title = title; self.position = position; self.isComplete = isComplete
    }
}

public struct NightSettings: Equatable, Codable, Sendable {
    public var enabled: Bool
    public var hour: Int
    public var minute: Int
    public init(enabled: Bool = false, hour: Int = 22, minute: Int = 0) {
        self.enabled = enabled; self.hour = hour; self.minute = minute
    }
    public var isValid: Bool { (0...23).contains(hour) && (0...59).contains(minute) }
}

public struct FocusRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let duration: TimeInterval
    public let finishedAt: Date
}

public enum MomentumError: LocalizedError {
    case invalidTitle, taskLimit, stepLimit, missingRecord, invalidSettings, invalidTimer
    case database(String), newerDatabase, backupDestination, migration(String)
    public var errorDescription: String? {
        switch self {
        case .invalidTitle: return "Enter a title with 1–200 characters."
        case .taskLimit: return "Your Daily Three is full. Remove a task before adding another."
        case .stepLimit: return "Keep your shutdown routine to ten steps or fewer."
        case .missingRecord: return "This item is no longer available. Refresh and try again."
        case .invalidSettings: return "Choose a valid reminder time."
        case .invalidTimer: return "The saved timer is invalid. Its data has been kept; restore a backup or contact support."
        case .database(let detail): return "The local database could not complete this change. \(detail)"
        case .newerDatabase: return "This database was created by a newer Momentum version. Update Momentum to open it."
        case .backupDestination: return "Choose a new backup file outside Momentum’s database folder."
        case .migration(let detail): return "Your previous data could not be imported. The original has been kept. \(detail)"
        }
    }
}

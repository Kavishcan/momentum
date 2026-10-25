import Foundation
import SwiftData

@Model
public final class DailyTask {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var dayKey: String
    public var createdAt: Date
    public var isComplete: Bool

    public init(title: String, dayKey: String, createdAt: Date = .now) {
        id = UUID()
        self.title = title
        self.dayKey = dayKey
        self.createdAt = createdAt
        isComplete = false
    }
}

@Model
public final class RoutineStep {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var position: Int
    public var completedNightKey: String?

    public init(title: String, position: Int) {
        id = UUID()
        self.title = title
        self.position = position
    }
}

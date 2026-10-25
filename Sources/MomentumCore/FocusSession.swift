import Foundation

public struct FocusSession: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable { case idle, running, paused, finished }
    public private(set) var phase: Phase = .idle
    public private(set) var duration: TimeInterval = 600
    public private(set) var deadline: Date?
    public private(set) var pausedRemaining: TimeInterval = 0
    public private(set) var taskTitle = "One small step"

    public init() {}

    public mutating func start(minutes: Int, taskTitle: String, now: Date = .now) {
        guard [10, 25].contains(minutes) else { return }
        duration = TimeInterval(minutes * 60)
        deadline = now.addingTimeInterval(duration)
        pausedRemaining = 0
        self.taskTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "One small step" : taskTitle
        phase = .running
    }

    public func remaining(at now: Date = .now) -> TimeInterval {
        switch phase {
        case .running: return max(0, (deadline ?? now).timeIntervalSince(now))
        case .paused: return pausedRemaining
        case .idle: return duration
        case .finished: return 0
        }
    }

    @discardableResult
    public mutating func reconcile(now: Date = .now) -> Bool {
        guard phase == .running, remaining(at: now) <= 0 else { return false }
        phase = .finished
        deadline = nil
        return true
    }

    public mutating func pause(now: Date = .now) {
        guard phase == .running else { return }
        if reconcile(now: now) { return }
        pausedRemaining = remaining(at: now)
        deadline = nil
        phase = .paused
    }

    public mutating func resume(now: Date = .now) {
        guard phase == .paused else { return }
        deadline = now.addingTimeInterval(pausedRemaining)
        phase = .running
    }

    public mutating func reset() { self = FocusSession() }

    public func clockText(at now: Date = .now) -> String {
        let seconds = Int(ceil(remaining(at: now)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

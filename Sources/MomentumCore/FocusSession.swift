import Foundation

public struct FocusSession: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable { case idle, running, paused, finished }
    public private(set) var id = UUID()
    public private(set) var phase: Phase = .idle
    public private(set) var duration: TimeInterval = 600
    public private(set) var deadline: Date?
    public private(set) var finishedAt: Date?
    public private(set) var pausedRemaining: TimeInterval = 0
    public private(set) var taskTitle = "One small step"

    public init() {}

    public var isValid: Bool {
        guard [600.0, 1500.0].contains(duration), pausedRemaining.isFinite,
              (0...duration).contains(pausedRemaining), taskTitle.count <= 200 else { return false }
        if phase == .running { return deadline != nil && deadline!.timeIntervalSince1970.isFinite }
        return deadline == nil
    }

    private enum CodingKeys: String, CodingKey { case id, phase, duration, deadline, finishedAt, pausedRemaining, taskTitle }
    public init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self)
        id = try data.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        phase = try data.decode(Phase.self, forKey: .phase)
        duration = try data.decode(TimeInterval.self, forKey: .duration)
        deadline = try data.decodeIfPresent(Date.self, forKey: .deadline)
        finishedAt = try data.decodeIfPresent(Date.self, forKey: .finishedAt)
        pausedRemaining = try data.decode(TimeInterval.self, forKey: .pausedRemaining)
        taskTitle = try data.decode(String.self, forKey: .taskTitle)
    }

    public mutating func start(minutes: Int, taskTitle: String, now: Date = .now) {
        guard [10, 25].contains(minutes) else { return }
        id = UUID()
        duration = TimeInterval(minutes * 60)
        deadline = now.addingTimeInterval(duration)
        finishedAt = nil
        pausedRemaining = 0
        self.taskTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "One small step" : String(taskTitle.prefix(200))
        phase = .running
    }

    public func remaining(at now: Date = .now) -> TimeInterval {
        switch phase {
        case .running: return min(duration, max(0, (deadline ?? now).timeIntervalSince(now)))
        case .paused: return pausedRemaining
        case .idle: return duration
        case .finished: return 0
        }
    }

    @discardableResult
    public mutating func reconcile(now: Date = .now) -> Bool {
        guard phase == .running, remaining(at: now) <= 0 else { return false }
        phase = .finished
        finishedAt = deadline ?? now
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

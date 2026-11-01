import Combine
import Foundation

@MainActor
public final class MomentumStore: ObservableObject {
    @Published public private(set) var tasks: [MomentumTask] = []
    @Published public private(set) var steps: [ShutdownStep] = []
    @Published public private(set) var history: [FocusRecord] = []
    @Published public private(set) var days: [String] = []
    @Published public private(set) var settings = NightSettings()
    @Published public private(set) var dayKey = ""
    @Published public private(set) var nightKey = ""
    @Published public var errorMessage: String?
    public let database: MomentumDatabase

    public init(database: MomentumDatabase, now: Date = .now) throws {
        self.database = database
        try reload(now: now)
    }
    private func reload(now: Date) throws {
        let day = DayClock.dayKey(for: now), night = DayClock.nightKey(for: now)
        let newTasks = try database.tasks(on: day), newSteps = try database.steps(on: night)
        let newSettings = try database.settings(), newHistory = try database.focusHistory(), newDays = try database.days()
        tasks = newTasks; steps = newSteps; settings = newSettings; history = newHistory; days = newDays
        dayKey = day; nightKey = night
    }
    public func refresh(now: Date = .now) { do { try reload(now: now) } catch { errorMessage = error.localizedDescription } }
    @discardableResult
    public func perform(_ action: () throws -> Void, now: Date = .now) -> Bool {
        do { try action(); try reload(now: now); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }
    public func addTask(_ title: String, now: Date = .now) -> Bool {
        perform({ try database.addTask(title, day: DayClock.dayKey(for: now), now: now) }, now: now)
    }
    public func rename(_ task: MomentumTask, to title: String) -> Bool { perform { try database.renameTask(task.id, to: title) } }
    public func toggle(_ task: MomentumTask) { perform { try database.setTaskComplete(task.id, !task.isComplete) } }
    public func delete(_ task: MomentumTask) -> Bool { perform { try database.deleteTask(task.id) } }
    public func addStep(_ title: String) -> Bool { perform { try database.addStep(title) } }
    public func rename(_ step: ShutdownStep, to title: String) -> Bool { perform { try database.renameStep(step.id, to: title) } }
    public func toggle(_ step: ShutdownStep, now: Date = .now) {
        perform({ try database.setStepComplete(step.id, night: DayClock.nightKey(for: now), !step.isComplete) }, now: now)
    }
    public func delete(_ step: ShutdownStep) -> Bool { perform { try database.deleteStep(step.id) } }
    public func saveSettings(_ value: NightSettings) -> Bool { perform { try database.saveSettings(value) } }
}

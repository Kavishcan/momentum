import Combine
import Foundation
import SwiftData

@MainActor
public final class MomentumStore: ObservableObject {
    @Published public private(set) var tasks: [DailyTask] = []
    @Published public private(set) var steps: [RoutineStep] = []
    @Published public private(set) var dayKey = ""
    @Published public private(set) var nightKey = ""
    @Published public var errorMessage: String?

    private let context: ModelContext
    private let defaults: UserDefaults

    public init(container: ModelContainer, defaults: UserDefaults = .standard, now: Date = .now) {
        context = ModelContext(container)
        context.autosaveEnabled = false
        self.defaults = defaults
        refresh(now: now)
        if !defaults.bool(forKey: "routineSeeded.v1"), errorMessage == nil {
            if steps.isEmpty {
                ["Park your phone away from bed", "Write tomorrow’s first small step", "Close the laptop and wind down"]
                    .enumerated().forEach { context.insert(RoutineStep(title: $0.element, position: $0.offset)) }
                save()
            }
            if errorMessage == nil { defaults.set(true, forKey: "routineSeeded.v1") }
        }
    }

    public func refresh(now: Date = .now, timeZone: TimeZone = .current) {
        dayKey = DayClock.dayKey(for: now, timeZone: timeZone)
        nightKey = DayClock.nightKey(for: now, timeZone: timeZone)
        reload()
    }

    private func reload() {
        do {
            let key = dayKey
            tasks = try context.fetch(FetchDescriptor<DailyTask>(
                predicate: #Predicate { $0.dayKey == key },
                sortBy: [SortDescriptor(\DailyTask.createdAt)]
            ))
            steps = try context.fetch(FetchDescriptor<RoutineStep>(sortBy: [SortDescriptor(\RoutineStep.position)]))
        } catch {
            errorMessage = "Momentum couldn’t read your local data. \(error.localizedDescription)"
        }
    }

    private func save() {
        do { try context.save() }
        catch {
            context.rollback()
            errorMessage = "Your change wasn’t saved. \(error.localizedDescription)"
        }
        reload()
    }

    public func addTask(_ title: String, now: Date = .now) {
        refresh(now: now)
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard tasks.count < 3 else {
            errorMessage = "Keep today to three tasks. Edit or remove one to make room."
            return
        }
        context.insert(DailyTask(title: String(clean.prefix(200)), dayKey: dayKey, createdAt: now))
        save()
    }

    public func rename(_ task: DailyTask, to title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        task.title = String(clean.prefix(200))
        save()
    }

    public func toggle(_ task: DailyTask) { task.isComplete.toggle(); save() }
    public func delete(_ task: DailyTask) { context.delete(task); save() }

    public func addStep(_ title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, steps.count < 10 else { return }
        context.insert(RoutineStep(title: String(clean.prefix(200)), position: (steps.map(\.position).max() ?? -1) + 1))
        save()
    }

    public func rename(_ step: RoutineStep, to title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        step.title = String(clean.prefix(200))
        save()
    }

    public func toggle(_ step: RoutineStep, now: Date = .now) {
        refresh(now: now)
        step.completedNightKey = step.completedNightKey == nightKey ? nil : nightKey
        save()
    }

    public func delete(_ step: RoutineStep) { context.delete(step); save() }
}

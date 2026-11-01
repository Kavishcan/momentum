import Combine
import Foundation
import MomentumCore

@MainActor
final class FocusController: ObservableObject {
    @Published private(set) var session: FocusSession
    @Published private(set) var now: Date
    @Published var errorMessage: String?
    var onCompletion: (() -> Void)?
    private let database: MomentumDatabase
    private var ticker: Task<Void, Never>?

    init(database: MomentumDatabase, now: Date = .now, ticking: Bool = true) throws {
        self.database = database; self.now = now
        var restored = try database.session()
        if restored.reconcile(now: now) { try database.saveSession(restored, now: now) }
        session = restored
        if ticking {
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { break }
                    self?.tick()
                }
            }
        }
    }
    deinit { ticker?.cancel() }
    func tick(at date: Date = .now) {
        now = date
        var changed = session
        if changed.reconcile(now: date) { commit(changed, now: date) }
    }
    @discardableResult
    private func commit(_ value: FocusSession, now: Date = .now) -> Bool {
        do {
            try database.saveSession(value, now: now)
            let finished = value.phase == .finished && session.phase != .finished
            session = value
            if finished { onCompletion?() }
            return true
        }
        catch { if errorMessage != error.localizedDescription { errorMessage = error.localizedDescription }; return false }
    }
    func start(minutes: Int, title: String) {
        guard session.phase == .idle || session.phase == .finished else { return }
        guard [10,25].contains(minutes) else { return }
        var value = FocusSession(); now = .now
        value.start(minutes: minutes, taskTitle: title, now: now)
        commit(value)
    }
    func pause() { var value = session; value.pause(); commit(value) }
    func resume() { var value = session; value.resume(); now = .now; commit(value) }
    func reset() { commit(FocusSession()) }
}

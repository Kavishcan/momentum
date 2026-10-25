import Combine
import Foundation
import MomentumCore

@MainActor
final class FocusController: ObservableObject {
    @Published private(set) var session: FocusSession
    @Published private(set) var now = Date.now
    @Published var errorMessage: String?
    private let defaults: UserDefaults
    private var ticker: Task<Void, Never>?
    private let key = "focus.session.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key) {
            do { session = try JSONDecoder().decode(FocusSession.self, from: data) }
            catch {
                session = FocusSession()
                errorMessage = "The previous timer couldn’t be restored. Your tasks are safe."
            }
        } else { session = FocusSession() }
        if session.reconcile() { persist() }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
                self?.tick()
            }
        }
    }

    deinit { ticker?.cancel() }

    private func tick() {
        now = .now
        // Persist transitions only; the deadline replaces per-second disk writes.
        if session.reconcile(now: now) { persist() }
    }

    func start(minutes: Int, title: String) {
        session.start(minutes: minutes, taskTitle: title)
        now = .now
        persist()
    }

    func pause() { session.pause(); persist() }
    func resume() { session.resume(); now = .now; persist() }
    func reset() { session.reset(); persist() }

    private func persist() {
        do { defaults.set(try JSONEncoder().encode(session), forKey: key) }
        catch { errorMessage = "The timer couldn’t be saved. \(error.localizedDescription)" }
    }
}

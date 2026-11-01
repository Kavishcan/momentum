import Combine
import Foundation

public enum ReminderAuthorization: Sendable { case unknown, allowed, denied }
@MainActor
public protocol LocalReminderClient {
    func authorization() async -> ReminderAuthorization
    func requestAuthorization() async throws -> Bool
    func schedule(_ settings: NightSettings) async throws
    func cancel() async
    func sendTest() async throws
    func focusFinished() async
}

@MainActor
public final class ReminderCoordinator: ObservableObject {
    @Published public private(set) var status = "Reminders are off."
    @Published public private(set) var busy = false
    private let client: any LocalReminderClient
    private let database: MomentumDatabase
    private var revision = 0
    private var operation: Task<Void, Never>?
    public init(database: MomentumDatabase, client: any LocalReminderClient) {
        self.database = database; self.client = client
    }
    public func requestPermission() async throws -> Bool { try await client.requestAuthorization() }
    public func synchronize() {
        revision += 1
        let token = revision
        let previous = operation
        busy = true
        operation = Task {
            await previous?.value
            guard token == revision else { return }
            defer { if token == revision { busy = false } }
            do {
                let settings = try database.settings()
                guard settings.enabled else { await client.cancel(); status = "Reminders are off."; return }
                guard await client.authorization() == .allowed else {
                    await client.cancel()
                    status = "Permission is off. Allow Momentum in System Settings → Notifications, then refresh."
                    return
                }
                // Adding the same identifier replaces the request without first losing a working schedule.
                try await client.schedule(settings)
                status = "Scheduled daily at \(String(format: "%02d:%02d", settings.hour, settings.minute)). macOS Focus may silence alerts."
            } catch { status = "Reminder not scheduled: \(error.localizedDescription). Refresh to retry." }
        }
    }
    public func waitUntilIdle() async { await operation?.value }
    public func test() async throws {
        guard await client.authorization() == .allowed else { throw MomentumError.database("Allow notifications first, then send a test.") }
        try await client.sendTest()
        status = "Test requested for five seconds from now. Check your macOS notification settings if it doesn’t appear."
    }
    public func notifyFocusFinished() { Task { await client.focusFinished() } }
}

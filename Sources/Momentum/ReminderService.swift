import AppKit
import Foundation
import MomentumCore
import UserNotifications

@MainActor
final class SystemReminderClient: LocalReminderClient {
    private var center: UNUserNotificationCenter { .current() }
    func authorization() async -> ReminderAuthorization {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional ? .allowed : .denied
    }
    func requestAuthorization() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound]) }
    func schedule(_ settings: NightSettings) async throws {
        guard let plan = ReminderPlan(hour: settings.hour, minute: settings.minute) else { throw MomentumError.invalidSettings }
        let content = UNMutableNotificationContent()
        content.title = "Time to land the day"
        content.body = "Open Momentum for your Night Shutdown checklist. One calm step at a time."
        try await center.add(UNNotificationRequest(identifier: ReminderPlan.identifier, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: plan.dateComponents, repeats: true)))
    }
    func cancel() async {
        center.removePendingNotificationRequests(withIdentifiers: [ReminderPlan.identifier, "momentum.test"])
        center.removeDeliveredNotifications(withIdentifiers: [ReminderPlan.identifier])
    }
    func sendTest() async throws {
        let content = UNMutableNotificationContent()
        content.title = "Momentum reminders are ready"
        content.body = "This is your test reminder. Open Momentum to continue your routine."
        try await center.add(UNNotificationRequest(identifier: "momentum.test", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }
    func focusFinished() async {
        guard await authorization() == .allowed else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your focus session is complete"
        content.body = "That counts. Take a breath before the next thing."
        try? await center.add(UNNotificationRequest(identifier: "momentum.focus-finished", content: content, trigger: nil))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) { UNUserNotificationCenter.current().delegate = self }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { sender.windows.first { $0.identifier?.rawValue == "dashboard" || $0.title == "Momentum" }?.makeKeyAndOrderFront(nil) }
        return true
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .momentumOpenNight, object: nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        completionHandler()
    }
}
extension Notification.Name { static let momentumOpenNight = Notification.Name("momentum.open-night") }

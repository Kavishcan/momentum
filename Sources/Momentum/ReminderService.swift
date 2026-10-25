import AppKit
import Combine
import Foundation
import MomentumCore
import UserNotifications

@MainActor
final class ReminderService: ObservableObject {
    @Published private(set) var status = "Reminders are off."
    @Published private(set) var isWorking = false
    private let center = UNUserNotificationCenter.current()
    private var queuedUpdate: Task<Void, Never>?
    private var revision = 0

    func requestPermission() async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            let granted = try await center.requestAuthorization(options: [.alert])
            if !granted { status = "Notifications are off in System Settings → Notifications → Momentum." }
            return granted
        } catch {
            status = "Couldn’t enable notifications: \(error.localizedDescription)"
            return false
        }
    }

    /// Serialize OS requests so rapid time edits cannot leave an older reminder behind.
    func configure(enabled: Bool, hour: Int, minute: Int) {
        revision += 1
        let currentRevision = revision
        let previous = queuedUpdate
        queuedUpdate = Task {
            await previous?.value
            guard currentRevision == revision else { return }
            center.removePendingNotificationRequests(withIdentifiers: [ReminderPlan.identifier])
            guard enabled else { status = "Reminders are off."; return }
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                status = "Allow notifications in System Settings → Notifications → Momentum."
                return
            }
            guard let plan = ReminderPlan(hour: hour, minute: minute) else {
                status = "Choose a valid reminder time."
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Time to land the day"
            content.body = "Open Momentum for your Night Shutdown checklist. One calm step at a time."
            // Quiet by default: no notification sound or sensitive task titles.
            let request = UNNotificationRequest(
                identifier: ReminderPlan.identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: plan.dateComponents, repeats: true)
            )
            do {
                try await center.add(request)
                status = "Daily reminder scheduled. macOS Focus may silence it."
            } catch { status = "Couldn’t schedule the reminder: \(error.localizedDescription)" }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}

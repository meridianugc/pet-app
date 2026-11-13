import Foundation
import PetCore
import UserNotifications

/// Asks for permission and keeps local reminders lined up with the pet's stats.
@MainActor
final class PetNotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter
    private let planner: NotificationPlanner

    override init() {
        center = .current()
        planner = NotificationPlanner()
        super.init()
        center.delegate = self
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func reschedule(pet: Pet?, now: Date, includeAlreadyLow: Bool) async {
        let removable = PlannedNotification.allIDs.filter { $0 != PlannedNotification.testID }
        center.removePendingNotificationRequests(withIdentifiers: removable)
        guard let pet else { return }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let items = planner.plan(pet: pet, now: now, includeAlreadyLow: includeAlreadyLow)
        for item in items {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.threadIdentifier = "pocket-pet"
            let interval = max(1, item.fireAt.timeIntervalSince(now))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// The system calls this off the main actor. It does not touch scheduler state.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

#if DEBUG
    func sendTestReminder(petName: String) async -> String {
        let allowed = await requestAuthorization()
        let status = await authorizationStatus()
        guard allowed || status == .authorized || status == .provisional else {
            return "Reminders are off. Turn them on in Settings, then try again."
        }
        let content = UNMutableNotificationContent()
        content.title = "\(petName) says hello"
        content.body = "This is a test reminder from Pocket Pet."
        content.sound = .default
        content.threadIdentifier = "pocket-pet"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: PlannedNotification.testID,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
            return "A test reminder arrives in about 5 seconds."
        } catch {
            return "The test reminder could not be scheduled."
        }
    }
#endif
}

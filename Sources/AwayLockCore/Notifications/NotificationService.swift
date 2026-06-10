import Foundation
import UserNotifications

@MainActor
public final class NotificationService {
    public init() {}

    public func requestAuthorizationIfNeeded(settings: ProximitySettingsSnapshot) {
        guard settings.showNotifications else {
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func send(title: String, body: String, settings: ProximitySettingsSnapshot) {
        guard settings.showNotifications else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: "awaylock-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

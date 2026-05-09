import Foundation
import UserNotifications

/// Wires the "Daily Reconnect — 5 people every morning" promise from the
/// paywall to a real recurring local notification at 8:00 AM. Scheduled when
/// the user becomes premium; cancelled when premium ends.
///
/// Side-effect of `sync(isPremium:)`:
///   - if premium: ensure the daily-reconnect notification request exists
///   - if not premium: ensure it does not exist
enum DailyReconnectNotification {
    static let identifier = "relationos.daily-reconnect"
    static let hour = 8
    static let minute = 0

    @MainActor
    static func sync(isPremium: Bool) async {
        let center = UNUserNotificationCenter.current()
        if !isPremium {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }
        // Premium → ensure scheduled. Quietly request authorization if not
        // determined; do not nag if denied.
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if !granted { return }
            } catch {
                return
            }
        case .denied:
            return
        case .authorized, .ephemeral, .provisional:
            break
        @unknown default:
            return
        }
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        if pending.contains(identifier) { return }
        let content = UNMutableNotificationContent()
        content.title = "Daily Reconnect"
        content.body = "5 people you haven't talked to in a while. Open RelationOS to see who."
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}

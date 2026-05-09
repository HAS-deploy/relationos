import Foundation
import SwiftUI
import UserNotifications

/// Wraps `UNUserNotificationCenter` for scheduling local reminders. The free
/// tier can schedule reminders — only "smart" (context-aware) reminders are
/// premium-gated, and that gating happens at the call site, not here.
struct ReminderManager {
    enum AuthStatus { case notDetermined, denied, authorized, provisional }

    func currentStatus() async -> AuthStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized, .ephemeral: return .authorized
        case .provisional: return .provisional
        @unknown default: return .denied
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Schedule a one-shot reminder at a specific date. Replaces any pending
    /// request with the same identifier.
    func scheduleOneShotReminder(
        identifier: String,
        title: String,
        body: String,
        fireAt: Date
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    /// Schedule a repeating daily reminder at a given time of day.
    /// Used by the daily reconnect notification.
    func scheduleDailyReminder(
        identifier: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    func cancel(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func pendingIdentifiers() async -> [String] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.map { $0.identifier }
    }
}

// Make ReminderManager injectable via environment without requiring ObservableObject.
private struct ReminderManagerKey: EnvironmentKey {
    static let defaultValue = ReminderManager()
}

extension EnvironmentValues {
    var reminders: ReminderManager {
        get { self[ReminderManagerKey.self] }
        set { self[ReminderManagerKey.self] = newValue }
    }
}

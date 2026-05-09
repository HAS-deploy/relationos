import Foundation
import SwiftUI

/// Analytics is intentionally abstracted so a real provider could be wired
/// in later without touching call sites. **RelationOS does not include any
/// third-party analytics SDK** (privacy posture — see
/// docs/apple-review-risk-profile.md §5/§7). The default impl logs to the
/// console in DEBUG only and is a complete no-op in Release.
enum AnalyticsEvent: String {
    case contactAdded = "contact_added"
    case reminderEnabled = "reminder_enabled"
    case paywallViewed = "paywall_viewed"
    case purchaseStarted = "purchase_started"
    case purchaseCompleted = "purchase_completed"
    case purchaseRestored = "purchase_restored"
    case dailyReconnectViewed = "daily_reconnect_viewed"
    case settingsDeleteAllData = "settings_delete_all_data"
}

protocol AnalyticsService {
    func track(_ event: AnalyticsEvent, properties: [String: String])
}

extension AnalyticsService {
    func track(_ event: AnalyticsEvent) { track(event, properties: [:]) }
}

struct ConsoleAnalytics: AnalyticsService {
    func track(_ event: AnalyticsEvent, properties: [String: String]) {
        #if DEBUG
        let props = properties.isEmpty ? "" : " " + properties.map { "\($0)=\($1)" }.joined(separator: " ")
        print("[analytics] \(event.rawValue)\(props)")
        #endif
    }
}

struct NoopAnalytics: AnalyticsService {
    func track(_ event: AnalyticsEvent, properties: [String: String]) {}
}

// Environment injection
private struct AnalyticsKey: EnvironmentKey {
    static let defaultValue: AnalyticsService = NoopAnalytics()
}

extension EnvironmentValues {
    var analytics: AnalyticsService {
        get { self[AnalyticsKey.self] }
        set { self[AnalyticsKey.self] = newValue }
    }
}

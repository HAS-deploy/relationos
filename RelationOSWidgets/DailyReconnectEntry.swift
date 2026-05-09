import WidgetKit
import Foundation

/// One slot in the Daily Reconnect timeline. Either a list of overdue
/// contacts (Pro tier) or a single "Upgrade to Pro" placeholder (free tier
/// or empty contacts).
struct DailyReconnectEntry: TimelineEntry {
    let date: Date
    let isPremium: Bool
    let contacts: [DailyReconnectContact]

    static let placeholder = DailyReconnectEntry(
        date: Date(),
        isPremium: true,
        contacts: [
            DailyReconnectContact(id: UUID(), name: "Sarah Chen",     subtitle: "Last talked: 6 weeks ago"),
            DailyReconnectContact(id: UUID(), name: "Marcus Patel",   subtitle: "Last talked: 2 months ago"),
            DailyReconnectContact(id: UUID(), name: "Emily Rodriguez", subtitle: "Last talked: 11 weeks ago"),
            DailyReconnectContact(id: UUID(), name: "David Kim",      subtitle: "Last talked: 3 months ago"),
            DailyReconnectContact(id: UUID(), name: "Priya Shah",     subtitle: "Last talked: 4 months ago"),
        ]
    )

    static let upgradePrompt = DailyReconnectEntry(
        date: Date(),
        isPremium: false,
        contacts: []
    )
}

/// Light-weight contact view-model the widget renders. Intentionally a
/// separate value type so the widget extension does not have to depend on
/// the full `Contact` model API surface used by the main app.
struct DailyReconnectContact: Identifiable, Hashable {
    let id: UUID
    let name: String
    let subtitle: String
}

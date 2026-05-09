import Foundation

/// Read-only view of the main app's contacts blob, scoped to the widget
/// extension. Mirrors the keys used by `ContactsStore` and decodes the
/// same JSON format. Kept self-contained (no shared sources) so the widget
/// target stays a tiny independent extension.
enum DailyReconnectStore {

    static let appGroupIdentifier = "group.com.relationos.app"
    static let contactsKey = "relationos.contacts.v1"
    static let premiumKey  = "relationos.isPremium"

    /// Mirror of the main app's persisted `Contact` shape. Only the fields
    /// the widget renders are decoded here. `JSONDecoder` will silently
    /// ignore the remaining fields.
    private struct WidgetContact: Decodable {
        let id: UUID
        let name: String
        let lastInteractedAt: Date?
        let createdAt: Date
    }

    static func currentEntry(now: Date = Date()) -> DailyReconnectEntry {
        let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard
        let isPremium = defaults.bool(forKey: premiumKey)

        guard isPremium else { return .upgradePrompt }

        guard let data = defaults.data(forKey: contactsKey) else {
            return DailyReconnectEntry(date: now, isPremium: true, contacts: [])
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode([WidgetContact].self, from: data) else {
            return DailyReconnectEntry(date: now, isPremium: true, contacts: [])
        }

        let top = decoded.sorted { lhs, rhs in
            switch (lhs.lastInteractedAt, rhs.lastInteractedAt) {
            case (nil, nil): return lhs.createdAt < rhs.createdAt
            case (nil, _):   return true
            case (_, nil):   return false
            case let (l?, r?): return l < r
            }
        }.prefix(5)

        let contacts = top.map { wc -> DailyReconnectContact in
            let subtitle: String = {
                guard let last = wc.lastInteractedAt else { return "Never reconnected" }
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                return "Last talked: " + formatter.localizedString(for: last, relativeTo: now)
            }()
            return DailyReconnectContact(id: wc.id, name: wc.name, subtitle: subtitle)
        }

        return DailyReconnectEntry(date: now, isPremium: true, contacts: Array(contacts))
    }

    /// Next "morning" refresh time — 6am local on the following day.
    /// If we're already past today's 6am, we still return tomorrow's 6am
    /// so the timeline doesn't churn.
    static func nextMorningRefresh(after date: Date,
                                   calendar: Calendar = .current) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = 6
        comps.minute = 0
        comps.second = 0
        let todaySix = calendar.date(from: comps) ?? date.addingTimeInterval(3600)
        if todaySix > date { return todaySix }
        return calendar.date(byAdding: .day, value: 1, to: todaySix) ?? date.addingTimeInterval(24 * 3600)
    }
}

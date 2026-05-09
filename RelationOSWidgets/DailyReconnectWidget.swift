import WidgetKit
import SwiftUI

/// Daily Reconnect widget — surfaces 5 contacts the user is most overdue
/// to reach out to. Paywalled feature: free-tier users see an "Upgrade to
/// Pro" promo entry instead of the list.
///
/// Reads from the shared App Group container (`group.com.relationos.app`)
/// so it stays in lock-step with the main app's `ContactsStore`. The widget
/// is read-only; it never writes back. Timeline reloads happen on the main
/// app side via `WidgetReloader`.
struct DailyReconnectWidget: Widget {
    static let kind: String = "RelationOSDailyReconnectWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DailyReconnectProvider()) { entry in
            DailyReconnectWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Reconnect")
        .description("Five people every morning who are slipping away.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
        ])
    }
}

struct DailyReconnectProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyReconnectEntry {
        DailyReconnectEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyReconnectEntry) -> Void) {
        completion(DailyReconnectStore.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyReconnectEntry>) -> Void) {
        let entry = DailyReconnectStore.currentEntry()
        // Refresh once at the next 6am-ish boundary so the morning list
        // stays accurate without burning timeline-budget through the day.
        let nextRefresh = DailyReconnectStore.nextMorningRefresh(after: entry.date)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct DailyReconnectWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyReconnectEntry

    var body: some View {
        switch family {
        case .systemSmall:
            DailyReconnectSmallView(entry: entry)
        case .systemMedium:
            DailyReconnectMediumView(entry: entry)
        case .accessoryRectangular:
            DailyReconnectAccessoryRectangularView(entry: entry)
        default:
            DailyReconnectSmallView(entry: entry)
        }
    }
}

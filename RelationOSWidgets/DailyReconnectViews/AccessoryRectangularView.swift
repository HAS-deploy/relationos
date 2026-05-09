import SwiftUI
import WidgetKit

/// Lock-screen rectangular accessory — title + first overdue contact.
/// Tightest of the three families; one-line subtitle only.
struct DailyReconnectAccessoryRectangularView: View {
    let entry: DailyReconnectEntry

    var body: some View {
        Group {
            if entry.isPremium == false {
                VStack(alignment: .leading, spacing: 1) {
                    Text("RelationOS Pro").font(.caption2.bold())
                    Text("Tap to unlock daily reconnect.").font(.caption2)
                        .foregroundStyle(.secondary).lineLimit(1)
                }
            } else if let first = entry.contacts.first {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Reconnect today").font(.caption2.bold())
                    Text(first.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(first.subtitle).font(.caption2)
                        .foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Daily Reconnect").font(.caption2.bold())
                    Text("Add contacts to surface your morning list.")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackgroundIfAvailable(.clear)
    }
}

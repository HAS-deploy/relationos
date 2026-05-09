import SwiftUI
import WidgetKit

/// Compact systemSmall layout — title + 3 names. The home-screen sweet
/// spot for "five people every morning" is medium, but small still has
/// room for the top three.
struct DailyReconnectSmallView: View {
    let entry: DailyReconnectEntry

    var body: some View {
        Group {
            if entry.isPremium == false {
                upgradeBody
            } else if entry.contacts.isEmpty {
                emptyBody
            } else {
                listBody
            }
        }
        .containerBackgroundIfAvailable(Color(.systemBackground))
    }

    private var listBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill").font(.caption2)
                Text("Daily Reconnect").font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            ForEach(entry.contacts.prefix(3)) { c in
                Text(c.name).font(.subheadline.weight(.medium)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Daily Reconnect").font(.caption2.bold()).foregroundStyle(.secondary)
            Text("Add a few contacts to surface your morning list.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var upgradeBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "lock.fill").font(.caption)
            Text("RelationOS Pro").font(.caption.bold())
            Text("Unlock your daily reconnect list — five people every morning.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

extension View {
    /// `containerBackground` is required on iOS 17+. On 16 it's a no-op.
    @ViewBuilder
    func containerBackgroundIfAvailable<S: ShapeStyle>(_ style: S) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(style, for: .widget)
        } else {
            self.background(style)
        }
    }
}

import SwiftUI
import WidgetKit

/// systemMedium — full 5-name list with subtitle ("Last talked: 6 weeks ago").
struct DailyReconnectMediumView: View {
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
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill").font(.caption)
                Text("Daily Reconnect").font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            ForEach(entry.contacts.prefix(5)) { c in
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.name).font(.subheadline.weight(.medium)).lineLimit(1)
                    Text(c.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Reconnect").font(.caption.bold()).foregroundStyle(.secondary)
            Text("Add a few contacts in RelationOS — your morning reconnect list will populate here automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var upgradeBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.caption)
                Text("Upgrade to RelationOS Pro").font(.caption.bold())
            }
            Text("Get five people every morning who are slipping away.")
                .font(.subheadline)
            Text("Pro unlocks unlimited contacts, the daily reconnect list, and cooling-relationships highlighting.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

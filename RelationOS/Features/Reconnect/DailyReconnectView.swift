import SwiftUI

struct DailyReconnectView: View {
    @EnvironmentObject var contacts: ContactsStore
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.analytics) private var analytics

    let onGatedTap: (PremiumFeature) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.stackSpacing) {
                header
                if purchases.isPremium {
                    fullList
                } else {
                    lockedPreview
                }
            }
            .padding()
        }
        .navigationTitle("Reconnect")
        .onAppear { analytics.track(.dailyReconnectViewed) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Five people. Every morning.")
                .font(.title2.bold())
            Text("RelationOS surfaces a daily list of contacts you're losing touch with.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var fullList: some View {
        let candidates = contacts.dailyReconnectCandidates(limit: 5)
        return VStack(spacing: 8) {
            if candidates.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nothing to reconnect with yet.").font(.headline)
                        Text("Add a few contacts and log interactions over time. The list fills in as RelationOS notices cooling relationships.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(candidates) { contact in
                    Card { ContactRow(contact: contact) }
                }
            }
        }
    }

    /// Free-tier preview: render exactly one candidate (or a placeholder if
    /// none exist) plus a locked overlay that opens the paywall when tapped.
    private var lockedPreview: some View {
        let candidate = contacts.dailyReconnectCandidates(limit: 1).first
        return VStack(alignment: .leading, spacing: 12) {
            Card {
                if let c = candidate {
                    ContactRow(contact: c)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview").font(.headline).foregroundStyle(.secondary)
                        Text("Daily Reconnect surfaces 5 contacts every morning who are slipping away. Upgrade to see your list.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                onGatedTap(.dailyReconnect)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Theme.accent)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("See your full daily list")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Unlock the full Daily Reconnect list (5 people every morning) and cooling-relationships highlighting with RelationOS Pro.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                .padding(Theme.cardPadding)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

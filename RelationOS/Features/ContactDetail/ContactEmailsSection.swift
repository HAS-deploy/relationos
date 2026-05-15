import SwiftUI

/// The per-contact email digest section that ContactDetailView renders
/// above its existing interaction log. Three rendering states:
///   1. Outlook not connected → soft prompt with a "Connect in Settings" hint.
///   2. Connected, no email on this contact → "Add an email address to enable digest."
///   3. Connected + email present → digest + action items + recent subjects.
struct ContactEmailsSection: View {
    @EnvironmentObject var mail: MailCoordinator
    let contact: Contact

    var body: some View {
        Section {
            content
        } header: {
            HStack {
                Image(systemName: "envelope.badge")
                Text("Email digest")
            }
        }
        .task {
            // Only sync on appear if we haven't already this hour.
            if let last = mail.store.lastSyncAt,
               Date().timeIntervalSince(last) < 3600 { return }
            await mail.syncAndSummarize(contact)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !mail.isMicrosoftConfigured {
            Text("Email digest is in Pro and ships with Outlook / Microsoft 365 accounts. We're rolling out provider support gradually.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if !mail.isConnected {
            Button {
                // Settings owns the OAuth entry point; deep-link there.
                // For v1.1 we just hint; a richer flow can come later.
            } label: {
                Label("Connect Outlook in Settings", systemImage: "link.badge.plus")
            }
            .buttonStyle(.borderless)
            Text("Once connected, RelationOS pulls the most recent 15 emails per contact and summarizes them on-device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if (contact.email ?? "").isEmpty {
            Text("Add this contact's email address to enable the digest.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            connectedBody
        }
    }

    @ViewBuilder
    private var connectedBody: some View {
        let status = mail.statusByContact[contact.id] ?? .idle
        if let digest = mail.store.digest(for: contact.id) {
            digestRows(digest)
        } else if status == .syncing || status == .summarizing {
            HStack(spacing: 8) {
                ProgressView()
                Text(status == .syncing ? "Pulling recent emails…" : "Summarizing on-device…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Button("Generate digest") {
                Task { await mail.syncAndSummarize(contact) }
            }
        }
        if case .error(let msg) = status {
            Text(msg).font(.caption).foregroundStyle(.red)
        }
        let recent = mail.store.emails(for: contact.id)
        if !recent.isEmpty {
            DisclosureGroup("Recent subjects (\(recent.count))") {
                ForEach(recent.prefix(5), id: \.id) { e in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: e.isFromContact ? "arrow.down" : "arrow.up")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(e.subject).font(.subheadline)
                            Spacer()
                        }
                        Text(e.receivedAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func digestRows(_ digest: EmailDigest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !digest.summary.isEmpty {
                Text(digest.summary)
                    .font(.subheadline)
            }
            if let reason = digest.fallbackReason {
                Label(reason, systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !digest.actionItemsForMe.isEmpty {
                actionItems(title: "You owe", items: digest.actionItemsForMe, icon: "person.fill")
            }
            if !digest.actionItemsForThem.isEmpty {
                actionItems(title: "They owe", items: digest.actionItemsForThem, icon: "person")
            }
            HStack {
                Spacer()
                Button {
                    Task { await mail.syncAndSummarize(contact) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise").font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func actionItems(title: String, items: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.caption.bold())
            ForEach(items.indices, id: \.self) { idx in
                HStack(alignment: .top, spacing: 6) {
                    Text("•").foregroundStyle(.secondary)
                    Text(items[idx]).font(.subheadline)
                }
            }
        }
    }
}

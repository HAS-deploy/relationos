import Foundation
import Combine

/// On-device cache of email metadata + digests per contact.
///
/// Lives alongside `ContactsStore` in the App Group. Capped per contact so
/// we never persist more than the last N raw messages — older ones evict
/// as new ones arrive. Digests live separately and only regenerate when
/// the underlying email set changes (or the user pulls to refresh).
///
/// Storage layout in `group.com.relationos.app`:
///   `relationos.emails.v1` → JSON `[Email]`
///   `relationos.email_digests.v1` → JSON `[EmailDigest]`
@MainActor
final class EmailStore: ObservableObject {
    @Published private(set) var emails: [Email] = []
    @Published private(set) var digests: [EmailDigest] = []
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var lastSyncError: String?

    private let defaults: UserDefaults
    private let perContactCap = 15

    enum Keys {
        static let emails = "relationos.emails.v1"
        static let digests = "relationos.email_digests.v1"
        static let lastSync = "relationos.email_last_sync_at"
    }

    init(defaults: UserDefaults = ContactsStore.appGroupDefaults()) {
        self.defaults = defaults
        load()
    }

    // MARK: - Reads

    func emails(for contactId: UUID) -> [Email] {
        emails.filter { $0.contactId == contactId }
              .sorted { $0.receivedAt > $1.receivedAt }
    }

    func digest(for contactId: UUID) -> EmailDigest? {
        digests.first(where: { $0.contactId == contactId })
    }

    // MARK: - Writes

    /// Replace the cached email set for one contact with the freshly-fetched
    /// list. Invalidates the existing digest (so the summarizer re-runs on
    /// next read). Caller is responsible for actually running the summarizer
    /// asynchronously after this.
    func replaceEmails(_ rows: [Email], for contactId: UUID) {
        emails.removeAll(where: { $0.contactId == contactId })
        let trimmed = Array(rows.sorted { $0.receivedAt > $1.receivedAt }.prefix(perContactCap))
        emails.append(contentsOf: trimmed)
        digests.removeAll(where: { $0.contactId == contactId })
        persist()
    }

    func storeDigest(_ digest: EmailDigest) {
        digests.removeAll(where: { $0.contactId == digest.contactId })
        digests.append(digest)
        persist()
    }

    func recordSync(success: Bool, error: String? = nil) {
        if success {
            lastSyncAt = Date()
            lastSyncError = nil
            defaults.set(lastSyncAt, forKey: Keys.lastSync)
        } else {
            lastSyncError = error
        }
    }

    func wipe() {
        emails = []
        digests = []
        lastSyncAt = nil
        lastSyncError = nil
        defaults.removeObject(forKey: Keys.emails)
        defaults.removeObject(forKey: Keys.digests)
        defaults.removeObject(forKey: Keys.lastSync)
    }

    // MARK: - Persistence

    private func load() {
        if let data = defaults.data(forKey: Keys.emails),
           let decoded = try? JSONDecoder().decode([Email].self, from: data) {
            self.emails = decoded
        }
        if let data = defaults.data(forKey: Keys.digests),
           let decoded = try? JSONDecoder().decode([EmailDigest].self, from: data) {
            self.digests = decoded
        }
        lastSyncAt = defaults.object(forKey: Keys.lastSync) as? Date
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(emails) {
            defaults.set(data, forKey: Keys.emails)
        }
        if let data = try? JSONEncoder().encode(digests) {
            defaults.set(data, forKey: Keys.digests)
        }
    }
}

import Foundation
import Combine

// TODO(SwiftData migration): This is a simple in-memory + UserDefaults
// JSON-blob store for v1 scaffold. Replace with a SwiftData-backed
// implementation in v1.1 that preserves the same published API
// (`contacts`, `reminders`, `addContact`, `removeContact`, `upsertReminder`,
// `deleteAllData`). Views and tests should not need to change.

@MainActor
final class ContactsStore: ObservableObject {
    @Published private(set) var contacts: [Contact] = []
    @Published private(set) var reminders: [Reminder] = []
    @Published private(set) var interactions: [Interaction] = []

    private let defaults: UserDefaults

    /// App Group identifier shared between the main app and the widget
    /// extension. Both targets carry the matching entitlement so the
    /// widget can read the same contact / reminder JSON blobs the app
    /// writes here. Keep in sync with `RelationOS.entitlements` and
    /// `RelationOSWidgets.entitlements`.
    nonisolated static let appGroupIdentifier = "group.com.relationos.app"

    /// Shared UserDefaults instance pointing at the App Group container.
    /// Falls back to `.standard` only when the suite cannot be opened
    /// (e.g. unit tests running without entitlements). The widget always
    /// reads via `appGroupDefaults()` directly.
    nonisolated static func appGroupDefaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    enum Keys {
        static let contacts = "relationos.contacts.v1"
        static let reminders = "relationos.reminders.v1"
        static let interactions = "relationos.interactions.v1"
    }

    init(defaults: UserDefaults = ContactsStore.appGroupDefaults()) {
        self.defaults = defaults
        load()
    }

    // MARK: - Contacts

    func addContact(_ contact: Contact) {
        contacts.append(contact)
        persist()
    }

    /// Batch-insert from an importer. Dedupes against existing records:
    /// matches on (source, externalId) when both sides have one, otherwise
    /// falls back to case-insensitive name + (email || phone). Existing
    /// records get their phone/email backfilled when the incoming row has
    /// more data; the rest of the record (notes, tags, lastInteractedAt)
    /// is left alone so user edits aren't overwritten on re-import.
    ///
    /// Returns (inserted, mergedIntoExisting). Callers use this for the
    /// post-import confirmation toast ("Added 14, updated 3").
    @discardableResult
    func addContacts(_ batch: [Contact]) -> (inserted: Int, merged: Int) {
        var inserted = 0
        var merged = 0
        for incoming in batch {
            if let existingIdx = matchIndex(for: incoming) {
                var existing = contacts[existingIdx]
                var changed = false
                if existing.phone?.isEmpty != false, let p = incoming.phone, !p.isEmpty {
                    existing.phone = p; changed = true
                }
                if existing.email?.isEmpty != false, let e = incoming.email, !e.isEmpty {
                    existing.email = e; changed = true
                }
                if existing.externalId == nil, let x = incoming.externalId {
                    existing.externalId = x; changed = true
                }
                let existingIsManual = (existing.source == nil) || (existing.source == ContactSource.manual)
                if existingIsManual, let s = incoming.source, s != ContactSource.manual {
                    existing.source = s; changed = true
                }
                if changed {
                    contacts[existingIdx] = existing
                    merged += 1
                }
            } else {
                contacts.append(incoming)
                inserted += 1
            }
        }
        if inserted + merged > 0 { persist() }
        return (inserted, merged)
    }

    private func matchIndex(for incoming: Contact) -> Int? {
        // 1) Exact (source, externalId)
        if let src = incoming.source, let xid = incoming.externalId {
            for i in contacts.indices {
                let c = contacts[i]
                if c.source == src, c.externalId == xid {
                    return i
                }
            }
        }
        // 2) Same name + same email
        let lowerName = incoming.name.lowercased()
        if let raw = incoming.email {
            let lowerEmail = raw.lowercased()
            if !lowerEmail.isEmpty {
                for i in contacts.indices {
                    let c = contacts[i]
                    if c.name.lowercased() == lowerName,
                       (c.email?.lowercased() ?? "") == lowerEmail {
                        return i
                    }
                }
            }
        }
        // 3) Same name + same phone (digits only)
        if let p = incoming.phone, !p.isEmpty {
            let digits = String(p.filter { $0.isNumber })
            if !digits.isEmpty {
                for i in contacts.indices {
                    let c = contacts[i]
                    let existingDigits = String((c.phone ?? "").filter { $0.isNumber })
                    if c.name.lowercased() == lowerName, existingDigits == digits {
                        return i
                    }
                }
            }
        }
        return nil
    }

    func updateContact(_ contact: Contact) {
        guard let idx = contacts.firstIndex(where: { $0.id == contact.id }) else { return }
        contacts[idx] = contact
        persist()
    }

    func removeContact(at offsets: IndexSet) {
        contacts.remove(atOffsets: offsets)
        persist()
    }

    func removeContact(id: UUID) {
        contacts.removeAll { $0.id == id }
        reminders.removeAll { $0.contactId == id }
        interactions.removeAll { $0.contactId == id }
        persist()
    }

    func contact(id: UUID) -> Contact? {
        contacts.first(where: { $0.id == id })
    }

    /// Heuristic match by phone or email — used by CallObserver to find
    /// which contact a CXCall belonged to.
    func contact(matchingPhone phone: String?, email: String? = nil) -> Contact? {
        if let p = phone {
            let digits = String(p.filter { $0.isNumber })
            if !digits.isEmpty {
                for c in contacts {
                    let existing = String((c.phone ?? "").filter { $0.isNumber })
                    if existing == digits { return c }
                }
            }
        }
        if let raw = email {
            let lower = raw.lowercased()
            if !lower.isEmpty {
                for c in contacts where c.email?.lowercased() == lower {
                    return c
                }
            }
        }
        return nil
    }

    func touchInteraction(contactId: UUID, at date: Date = Date()) {
        guard let idx = contacts.firstIndex(where: { $0.id == contactId }) else { return }
        contacts[idx].lastInteractedAt = date
        persist()
    }

    // MARK: - Interactions

    /// Record a logged interaction and bump the contact's lastInteractedAt.
    func logInteraction(_ interaction: Interaction) {
        interactions.insert(interaction, at: 0)
        if let idx = contacts.firstIndex(where: { $0.id == interaction.contactId }) {
            if (contacts[idx].lastInteractedAt ?? .distantPast) < interaction.occurredAt {
                contacts[idx].lastInteractedAt = interaction.occurredAt
            }
        }
        // Cap at 500 to keep the UserDefaults blob bounded — pre-SwiftData.
        if interactions.count > 500 { interactions = Array(interactions.prefix(500)) }
        persist()
    }

    func interactionsFor(contactId: UUID) -> [Interaction] {
        interactions.filter { $0.contactId == contactId }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    // MARK: - Reminders

    func upsertReminder(_ reminder: Reminder) {
        if let idx = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[idx] = reminder
        } else {
            reminders.append(reminder)
        }
        persist()
    }

    func remindersFor(contactId: UUID) -> [Reminder] {
        reminders.filter { $0.contactId == contactId }
    }

    // MARK: - Wipe (Settings → Delete all data)

    func deleteAllData() {
        contacts = []
        reminders = []
        interactions = []
        defaults.removeObject(forKey: Keys.contacts)
        defaults.removeObject(forKey: Keys.reminders)
        defaults.removeObject(forKey: Keys.interactions)
    }

    // MARK: - Daily reconnect (paywalled feature)

    /// Top N contacts most overdue for reconnection. Currently a simple
    /// "oldest lastInteractedAt first, never-touched first" heuristic. In v1.1
    /// this will move to RelationOSStore + SwiftData with a real cadence
    /// model. For now this drives the DailyReconnectView preview.
    func dailyReconnectCandidates(limit: Int = 5) -> [Contact] {
        contacts.sorted { lhs, rhs in
            switch (lhs.lastInteractedAt, rhs.lastInteractedAt) {
            case (nil, nil): return lhs.createdAt < rhs.createdAt
            case (nil, _):   return true
            case (_, nil):   return false
            case let (l?, r?): return l < r
            }
        }
        .prefix(limit)
        .map { $0 }
    }

    // MARK: - Persistence

    private func load() {
        if let data = defaults.data(forKey: Keys.contacts),
           let decoded = try? JSONDecoder().decode([Contact].self, from: data) {
            self.contacts = decoded
        }
        if let data = defaults.data(forKey: Keys.reminders),
           let decoded = try? JSONDecoder().decode([Reminder].self, from: data) {
            self.reminders = decoded
        }
        if let data = defaults.data(forKey: Keys.interactions),
           let decoded = try? JSONDecoder().decode([Interaction].self, from: data) {
            self.interactions = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(contacts) {
            defaults.set(data, forKey: Keys.contacts)
        }
        if let data = try? JSONEncoder().encode(reminders) {
            defaults.set(data, forKey: Keys.reminders)
        }
        if let data = try? JSONEncoder().encode(interactions) {
            defaults.set(data, forKey: Keys.interactions)
        }
        WidgetReloader.reloadDailyReconnect()
    }
}

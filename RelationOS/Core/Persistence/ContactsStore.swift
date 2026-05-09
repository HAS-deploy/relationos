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
        persist()
    }

    func contact(id: UUID) -> Contact? {
        contacts.first(where: { $0.id == id })
    }

    func touchInteraction(contactId: UUID, at date: Date = Date()) {
        guard let idx = contacts.firstIndex(where: { $0.id == contactId }) else { return }
        contacts[idx].lastInteractedAt = date
        persist()
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
        defaults.removeObject(forKey: Keys.contacts)
        defaults.removeObject(forKey: Keys.reminders)
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
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(contacts) {
            defaults.set(data, forKey: Keys.contacts)
        }
        if let data = try? JSONEncoder().encode(reminders) {
            defaults.set(data, forKey: Keys.reminders)
        }
        WidgetReloader.reloadDailyReconnect()
    }
}

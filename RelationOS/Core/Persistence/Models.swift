import Foundation

// TODO(SwiftData migration): These plain-Swift structs are placeholders for
// what will become `@Model` classes once we wire SwiftData into v1.1. The
// API surface (`id`, `name`, `notes`, `tags`, `lastInteractedAt`,
// `createdAt`) is the long-lived contract; SwiftData rewrite should stay
// drop-in for the views.

struct Contact: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var notes: String
    var tags: [String]
    var lastInteractedAt: Date?
    var createdAt: Date

    // Added 2026-05-14 for contact import. All optional so existing
    // UserDefaults blobs (encoded before these fields existed) decode
    // cleanly — Codable will leave them nil. Persisted alongside the
    // existing fields.
    var phone: String?
    var email: String?
    /// Where this record came from. nil = manually entered pre-v1.1.
    var source: ContactSource?
    /// Provider-side identifier (Contacts CNContact id, Google People
    /// resourceName, Graph contact id, vCard UID). Used to dedupe re-imports.
    var externalId: String?

    init(id: UUID = UUID(),
         name: String,
         notes: String = "",
         tags: [String] = [],
         lastInteractedAt: Date? = nil,
         createdAt: Date = Date(),
         phone: String? = nil,
         email: String? = nil,
         source: ContactSource? = nil,
         externalId: String? = nil) {
        self.id = id
        self.name = name
        self.notes = notes
        self.tags = tags
        self.lastInteractedAt = lastInteractedAt
        self.createdAt = createdAt
        self.phone = phone
        self.email = email
        self.source = source
        self.externalId = externalId
    }
}

enum ContactSource: String, Codable, Hashable {
    case manual
    case phone        // iOS Contacts app via CNContactStore
    case vcard        // .vcf file (share sheet / document picker / pasted)
    case google       // Google People API
    case microsoft    // Microsoft Graph
}

struct Reminder: Identifiable, Hashable, Codable {
    var id: UUID
    var contactId: UUID
    var title: String
    var fireAt: Date

    init(id: UUID = UUID(),
         contactId: UUID,
         title: String,
         fireAt: Date) {
        self.id = id
        self.contactId = contactId
        self.title = title
        self.fireAt = fireAt
    }
}

/// User-logged interaction with a contact. iOS does not expose SMS,
/// iMessage, call history, or inbound email content to third-party apps,
/// so this is the manual substitute: each Log action records what kind
/// of interaction happened and when. `via` distinguishes a logged
/// outbound (we opened MFMessageCompose / MFMailCompose / `tel:`) from
/// a manually-recorded "I already talked to them" entry and from an
/// in-app CXCallObserver capture.
struct Interaction: Identifiable, Hashable, Codable {
    enum Kind: String, Codable, Hashable {
        case call
        case text
        case email
        case meeting
        case other
    }

    enum Via: String, Codable, Hashable {
        case manual            // user logged it after the fact
        case composer          // we opened the system compose sheet
        case callObserver      // CXCallObserver saw the call end in-app
    }

    var id: UUID
    var contactId: UUID
    var kind: Kind
    var via: Via
    var occurredAt: Date
    var notes: String

    init(id: UUID = UUID(),
         contactId: UUID,
         kind: Kind,
         via: Via,
         occurredAt: Date = Date(),
         notes: String = "") {
        self.id = id
        self.contactId = contactId
        self.kind = kind
        self.via = via
        self.occurredAt = occurredAt
        self.notes = notes
    }
}

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

    init(id: UUID = UUID(),
         name: String,
         notes: String = "",
         tags: [String] = [],
         lastInteractedAt: Date? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.notes = notes
        self.tags = tags
        self.lastInteractedAt = lastInteractedAt
        self.createdAt = createdAt
    }
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

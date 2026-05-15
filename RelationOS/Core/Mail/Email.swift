import Foundation

/// A single email message, normalized from Microsoft Graph.
/// We persist just the parts the summarizer + UI need — never the full
/// HTML body, and never the recipient list beyond the counterparty.
/// Older messages auto-evict via EmailStore's per-contact cap.
struct Email: Identifiable, Hashable, Codable {
    var id: String                 // Graph message id
    var contactId: UUID            // matched contact in ContactsStore
    var subject: String
    var bodyPreview: String        // Graph's bodyPreview field (~255 chars)
    var bodyPlain: String          // full body, plain-text rendering, used for summarization
    var receivedAt: Date
    var isFromContact: Bool        // counterparty sent it (true) or user did (false)
    var webLink: String?           // outlook.office.com link, optional
}

/// One summarization pass over a contact's recent emails.
/// Produced by `EmailSummarizer` (Apple Foundation Models on iOS 26+) or
/// a tiny rule-based fallback on older OSes. Stored per contact and
/// re-generated lazily — see `EmailStore.summary(for:)`.
struct EmailDigest: Hashable, Codable {
    var contactId: UUID
    var generatedAt: Date
    var emailCount: Int
    var summary: String                   // 1–3 sentence prose
    var actionItemsForMe: [String]        // things the user owes
    var actionItemsForThem: [String]      // things the contact owes
    /// nil when the digest was made on Foundation Models, set to a string
    /// explaining the fallback on older OSes ("Email summarization requires
    /// iOS 26 on an Apple Intelligence-eligible device").
    var fallbackReason: String?
}

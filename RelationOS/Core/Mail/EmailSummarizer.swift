import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device summarization of a contact's recent emails.
///
/// On iOS 26+ Apple-Intelligence-eligible devices we use Apple's
/// `LanguageModelSession` to produce a short prose summary plus two
/// action-item lists (what the user owes / what the contact owes).
/// Everything runs locally — Apple's model never leaves the device, and
/// neither do the emails.
///
/// On every other device we fall back to a rule-free "here are the most
/// recent N subjects" digest with a `fallbackReason` set so the UI can
/// explain why summarization isn't available. We never silently substitute
/// a worse summary; the user always knows whether they're seeing AI output.
///
/// Trigger: `EmailStore.replaceEmails()` invalidates the digest; the
/// caller can then `try await summarize()` and store the result.
struct EmailSummarizer {
    static let shared = EmailSummarizer()

    enum SummarizerError: Error {
        case unavailable(String)
        case modelFailed(String)
    }

    /// True when on-device LLM is reachable AND the device is
    /// Apple-Intelligence-eligible. The framework itself decides eligibility
    /// at the OS level; we just probe by attempting `LanguageModelSession()`.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return SystemLanguageModel.default.availability == .available
        }
        return false
        #else
        return false
        #endif
    }

    /// Build a digest for `contact` from `emails` (already sorted by
    /// `receivedAt` desc by EmailStore). At most ~12 messages are passed in
    /// — the prompt cap is roughly 16k tokens and we want plenty of headroom
    /// for the model's structured output.
    func summarize(contact: Contact, emails: [Email]) async -> EmailDigest {
        let limited = Array(emails.prefix(12))
        if limited.isEmpty {
            return EmailDigest(
                contactId: contact.id, generatedAt: Date(),
                emailCount: 0, summary: "No recent emails with this contact.",
                actionItemsForMe: [], actionItemsForThem: [],
                fallbackReason: nil
            )
        }
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                do {
                    return try await foundationModelDigest(contact: contact, emails: limited)
                } catch {
                    return fallback(contact: contact, emails: limited,
                                    reason: "Summarization failed (\(error)); showing subject list.")
                }
            case .unavailable(.deviceNotEligible):
                return fallback(contact: contact, emails: limited,
                                reason: "This device is not eligible for Apple Intelligence. Showing the subject list instead.")
            case .unavailable(.appleIntelligenceNotEnabled):
                return fallback(contact: contact, emails: limited,
                                reason: "Turn on Apple Intelligence in Settings to summarize on-device. Showing the subject list instead.")
            case .unavailable(.modelNotReady):
                return fallback(contact: contact, emails: limited,
                                reason: "The on-device model is still downloading. Showing the subject list for now.")
            case .unavailable:
                return fallback(contact: contact, emails: limited,
                                reason: "Email summarization is unavailable on this device. Showing the subject list instead.")
            @unknown default:
                return fallback(contact: contact, emails: limited,
                                reason: "Email summarization is unavailable on this device. Showing the subject list instead.")
            }
        }
        #endif
        return fallback(
            contact: contact, emails: limited,
            reason: "Email summarization requires iOS 26 on an Apple Intelligence–eligible iPhone or iPad. Showing the subject list instead."
        )
    }

    // MARK: - Foundation Models path

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private func foundationModelDigest(contact: Contact, emails: [Email]) async throws -> EmailDigest {
        let prompt = Self.buildPrompt(contact: contact, emails: emails)
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(to: prompt, generating: GeneratedDigest.self)
        let g = response.content
        return EmailDigest(
            contactId: contact.id, generatedAt: Date(),
            emailCount: emails.count,
            summary: g.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            actionItemsForMe: g.actionItemsForMe.filter { !$0.isEmpty },
            actionItemsForThem: g.actionItemsForThem.filter { !$0.isEmpty },
            fallbackReason: nil
        )
    }

    @available(iOS 26, *)
    @Generable
    struct GeneratedDigest {
        @Guide(description: "One- to three-sentence summary of the overall thread of emails. Mention the most recent topic and the relationship dynamic. Plain prose, no list.")
        var summary: String

        @Guide(description: "Concrete action items the USER (the app owner) has agreed to do or has been asked to do. Empty list if none. Each item ≤120 characters, imperative voice (\"Send proposal by Friday\").")
        var actionItemsForMe: [String]

        @Guide(description: "Concrete action items the CONTACT has agreed to do or has been asked to do. Empty list if none. Each item ≤120 characters, imperative voice describing what the contact will do (\"Send signed NDA\", \"Reply with feedback\").")
        var actionItemsForThem: [String]
    }

    private static let instructions: String = """
You summarize a private email thread between the app's user and one of their contacts. The user is the account holder (their address is the recipient when the contact sends mail, and the sender when the user sends mail).

Be terse and factual. Do not invent action items that aren't supported by the email text. Distinguish "the user agreed to do X" from "the contact agreed to do Y" based on who said what in the emails. If both parties have outstanding items, list each in the right bucket.
"""

    private static func buildPrompt(contact: Contact, emails: [Email]) -> String {
        let header = "Contact: \(contact.name) <\(contact.email ?? "no email")>\nEmails (most recent first):\n\n"
        let bodies = emails.enumerated().map { (idx, e) -> String in
            let who = e.isFromContact ? contact.name : "user"
            let when = e.receivedAt.formatted(date: .abbreviated, time: .shortened)
            let body = e.bodyPlain.prefix(1500)  // cap each body
            return "[\(idx + 1)] \(when) — \(who): \(e.subject)\n\(body)"
        }.joined(separator: "\n\n---\n\n")
        return header + bodies
    }
    #endif

    // MARK: - Fallback

    private func fallback(contact: Contact, emails: [Email], reason: String) -> EmailDigest {
        let subjects = emails.prefix(5).map { "• \($0.subject)" }.joined(separator: "\n")
        let summary = emails.isEmpty
            ? "No recent emails with this contact."
            : "Last \(emails.count) emails:\n\(subjects)"
        return EmailDigest(
            contactId: contact.id, generatedAt: Date(),
            emailCount: emails.count,
            summary: summary,
            actionItemsForMe: [],
            actionItemsForThem: [],
            fallbackReason: reason
        )
    }
}

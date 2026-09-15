import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device extraction of a contact note into structured memory:
/// a short brief, remembered facts, and suggested follow-ups.
///
/// Uses Apple's Foundation Models framework (`SystemLanguageModel` +
/// `LanguageModelSession` + `@Generable`) when the device reports
/// `.available`. Verified against Apple's current docs:
/// https://developer.apple.com/documentation/foundationmodels
///
/// Capability-check is required — the model is only present on
/// Apple Intelligence–eligible devices in supported regions, and
/// assets may still be downloading. When unavailable or generation
/// fails we degrade to a local heuristic sketch so the feature is
/// never a blank wall. Notes never leave the device. We do not
/// train, fine-tune, or upload anything.
struct ContactMemoryExtractor {
    static let shared = ContactMemoryExtractor()

    enum AvailabilityStatus: Equatable {
        case available
        case unavailable(String)
    }

    /// Probe Apple's documented availability API. Returns a
    /// user-facing reason when the model cannot run.
    static var status: AvailabilityStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                return .unavailable(unavailableMessage(reason))
            @unknown default:
                return .unavailable("On-device summarization is unavailable. Showing a local sketch from your notes instead.")
            }
        }
        return .unavailable(osUnsupportedReason)
        #else
        return .unavailable(osUnsupportedReason)
        #endif
    }

    static var isAvailable: Bool {
        if case .available = status { return true }
        return false
    }

    static let osUnsupportedReason =
        "On-device briefs need iOS 26 on an Apple Intelligence–eligible iPhone or iPad. Showing a local sketch from your notes instead."

    /// Extract structured memory for `contact`. Always returns a
    /// value — either model output or a heuristic fallback.
    func extract(contact: Contact, interactions: [Interaction] = []) async -> ContactMemory {
        let notes = contact.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if notes.isEmpty {
            return ContactMemory(
                brief: "No notes yet for \(contact.name).",
                facts: [],
                followUps: heuristicFollowUps(contact: contact, interactions: interactions),
                generatedAt: Date(),
                usedOnDeviceModel: false,
                fallbackReason: "Add a note first — there's nothing to extract."
            )
        }

        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                do {
                    return try await foundationExtract(contact: contact, interactions: interactions)
                } catch {
                    return heuristicExtract(
                        contact: contact,
                        interactions: interactions,
                        reason: "On-device model failed (\(error.localizedDescription)). Showing a local sketch instead."
                    )
                }
            case .unavailable(let reason):
                return heuristicExtract(
                    contact: contact,
                    interactions: interactions,
                    reason: Self.unavailableMessage(reason)
                )
            @unknown default:
                return heuristicExtract(
                    contact: contact,
                    interactions: interactions,
                    reason: "On-device summarization is unavailable. Showing a local sketch from your notes instead."
                )
            }
        }
        #endif

        return heuristicExtract(
            contact: contact,
            interactions: interactions,
            reason: Self.osUnsupportedReason
        )
    }

    // MARK: - Foundation Models path

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private func foundationExtract(contact: Contact, interactions: [Interaction]) async throws -> ContactMemory {
        let prompt = Self.buildPrompt(contact: contact, interactions: interactions)
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(to: prompt, generating: GeneratedMemory.self)
        let g = response.content
        return ContactMemory(
            brief: g.brief.trimmingCharacters(in: .whitespacesAndNewlines),
            facts: g.facts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            followUps: g.followUps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            generatedAt: Date(),
            usedOnDeviceModel: true,
            fallbackReason: nil
        )
    }

    @available(iOS 26, *)
    @Generable
    struct GeneratedMemory {
        @Guide(description: "Two or three sentences that a busy person can read in 10 seconds: who this is, how you know them, and what matters right now. Plain prose. No lists. Do not invent facts that are not in the notes.")
        var brief: String

        @Guide(description: "Concrete remembered facts from the notes (job, family, preferences, commitments). Empty if none. Each item ≤120 characters. No invented details.")
        var facts: [String]

        @Guide(description: "Suggested next follow-ups grounded in the notes or overdue contact. Empty if none. Each item ≤120 characters, imperative voice (\"Ask about the new role\", \"Send the intro\").")
        var followUps: [String]
    }

    private static let instructions: String = """
You extract structured relationship memory from private notes the user wrote about one contact. Everything stays on-device.

Be terse and factual. Never invent names, dates, jobs, or commitments that are not supported by the notes. If the notes are thin, keep the brief short and leave facts/follow-ups empty rather than guessing. Distinguish remembered facts from suggested next actions.
"""

    private static func buildPrompt(contact: Contact, interactions: [Interaction]) -> String {
        var lines: [String] = [
            "Contact name: \(contact.name)",
        ]
        if let email = contact.email, !email.isEmpty {
            lines.append("Email: \(email)")
        }
        if !contact.tags.isEmpty {
            lines.append("Tags: \(contact.tags.joined(separator: ", "))")
        }
        if let last = contact.lastInteractedAt {
            lines.append("Last interaction: \(last.formatted(date: .abbreviated, time: .omitted))")
        }
        lines.append("Notes:\n\(contact.notes)")
        if !interactions.isEmpty {
            let recent = interactions.prefix(5).map { item in
                "• \(item.kind.rawValue) (\(item.via.rawValue)) \(item.occurredAt.formatted(date: .abbreviated, time: .omitted))"
                    + (item.notes.isEmpty ? "" : " — \(item.notes.prefix(160))")
            }.joined(separator: "\n")
            lines.append("Recent logged interactions:\n\(recent)")
        }
        return lines.joined(separator: "\n")
    }

    @available(iOS 26, *)
    static func unavailableMessage(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device is not eligible for Apple Intelligence. Showing a local sketch from your notes instead."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to generate an on-device brief. Showing a local sketch instead."
        case .modelNotReady:
            return "The on-device model is still downloading. Showing a local sketch for now — try again shortly."
        @unknown default:
            return "On-device summarization is unavailable. Showing a local sketch from your notes instead."
        }
    }
    #endif

    // MARK: - Heuristic fallback (always available, no network)

    /// Visible to tests so we can assert fallback copy without a device model.
    func heuristicExtract(contact: Contact, interactions: [Interaction], reason: String) -> ContactMemory {
        let notes = contact.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentences = Self.splitSentences(notes)
        let brief: String
        if sentences.isEmpty {
            brief = "No notes yet for \(contact.name)."
        } else {
            brief = sentences.prefix(2).joined(separator: " ")
        }
        let skip = min(2, sentences.count)
        let facts = sentences
            .dropFirst(skip)
            .prefix(5)
            .map { String($0.prefix(120)) }
        return ContactMemory(
            brief: String(brief.prefix(280)),
            facts: Array(facts),
            followUps: heuristicFollowUps(contact: contact, interactions: interactions, notes: notes),
            generatedAt: Date(),
            usedOnDeviceModel: false,
            fallbackReason: reason
        )
    }

    private func heuristicFollowUps(contact: Contact, interactions: [Interaction], notes: String = "") -> [String] {
        var items: [String] = []
        let lower = notes.lowercased()
        if lower.contains("follow up") || lower.contains("follow-up") {
            items.append("Follow up on the open item in your notes")
        }
        if lower.contains("call") || lower.contains("phone") {
            items.append("Call \(contact.name)")
        }
        if lower.contains("email") || lower.contains("send") {
            items.append("Send a short note to \(contact.name)")
        }
        if let last = contact.lastInteractedAt {
            let days = max(0, Int(Date().timeIntervalSince(last) / 86400))
            if days >= 14 {
                items.append("Reach out — last logged contact was \(days) days ago")
            }
        } else if interactions.isEmpty {
            items.append("Log a first interaction after you next talk")
        }
        if items.isEmpty {
            items.append("Check in this week")
        }
        return Array(items.prefix(3))
    }

    private static func splitSentences(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ".!?\n")
        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }
    }
}

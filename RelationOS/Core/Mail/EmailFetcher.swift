import Foundation

/// Pulls recent messages per contact from Microsoft Graph.
///
/// Per contact we fetch the most recent N messages where the contact's
/// email appears as sender OR a top-level recipient. Graph's `$search`
/// is the simplest path — it indexes both to/from and subject. Filter
/// fallback is `$filter=from/emailAddress/address eq '…' or
/// toRecipients/any(t:t/emailAddress/address eq '…')` but search is
/// faster on large mailboxes and Graph caches it.
///
/// Throws on network / 401. The caller is responsible for refreshing
/// the token via `MicrosoftMailAuth.shared.currentAccessToken()` first
/// (this class doesn't own auth state).
@MainActor
final class EmailFetcher {
    enum FetcherError: Error {
        case notConnected
        case http(Int, String)
        case decode(String)
    }

    static let shared = EmailFetcher()
    private let session: URLSession = .shared
    private let limitPerContact = 15        // top N messages

    func fetchRecentEmails(for contact: Contact) async throws -> [Email] {
        guard let email = contact.email?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty else { return [] }

        let token = try await MicrosoftMailAuth.shared.currentAccessToken()

        // Graph $search query — escape quotes by doubling them per OData.
        let safeEmail = email.replacingOccurrences(of: "\"", with: "\"\"")
        let search = "\"from:\(safeEmail) OR to:\(safeEmail)\""
        var comps = URLComponents(string: "https://graph.microsoft.com/v1.0/me/messages")!
        comps.queryItems = [
            URLQueryItem(name: "$search", value: search),
            URLQueryItem(name: "$top", value: "\(limitPerContact)"),
            URLQueryItem(name: "$select", value:
                "id,subject,bodyPreview,body,receivedDateTime,from,toRecipients,webLink"),
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // ConsistencyLevel=eventual is required for $search per Graph docs
        req.setValue("eventual", forHTTPHeaderField: "ConsistencyLevel")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw FetcherError.http(0, "no response")
        }
        if http.statusCode == 401 {
            throw FetcherError.notConnected
        }
        if http.statusCode >= 300 {
            throw FetcherError.http(http.statusCode,
                                    String(data: data, encoding: .utf8)?.prefix(400).description ?? "")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetcherError.decode("not a JSON object")
        }
        let values = json["value"] as? [[String: Any]] ?? []
        return values.compactMap { mapToEmail($0, contactId: contact.id, contactEmail: email) }
    }

    private func mapToEmail(_ raw: [String: Any], contactId: UUID, contactEmail: String) -> Email? {
        guard let id = raw["id"] as? String else { return nil }
        let subject = (raw["subject"] as? String) ?? "(no subject)"
        let bodyPreview = (raw["bodyPreview"] as? String) ?? ""
        let bodyPlain = extractPlainBody(raw["body"]) ?? bodyPreview
        let receivedAt = parseGraphDate(raw["receivedDateTime"] as? String) ?? Date()
        let from = (raw["from"] as? [String: Any])?["emailAddress"] as? [String: Any]
        let fromAddress = (from?["address"] as? String) ?? ""
        let isFromContact = fromAddress.caseInsensitiveCompare(contactEmail) == .orderedSame
        let webLink = raw["webLink"] as? String
        return Email(
            id: id, contactId: contactId,
            subject: subject, bodyPreview: bodyPreview, bodyPlain: bodyPlain,
            receivedAt: receivedAt, isFromContact: isFromContact,
            webLink: webLink
        )
    }

    /// Graph returns body as `{ "content": "...", "contentType": "html"|"text" }`.
    /// We strip tags lossily for HTML — good enough for summarization input.
    private func extractPlainBody(_ raw: Any?) -> String? {
        guard let body = raw as? [String: Any],
              let content = body["content"] as? String else { return nil }
        if (body["contentType"] as? String)?.lowercased() == "text" {
            return content
        }
        return Self.stripHTML(content)
    }

    static func stripHTML(_ html: String) -> String {
        // Lossy but fast: drop tags + decode the common entities. Good
        // enough for an LLM input; we never display this string raw.
        var s = html
        // Remove <script> + <style> blocks first (with their contents).
        s = s.replacingOccurrences(
            of: "<(script|style)\\b[^>]*>[\\s\\S]*?</\\1>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        s = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities: [String: String] = [
            "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&apos;": "'",
        ]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseGraphDate(_ iso: String?) -> Date? {
        guard let iso = iso else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }
}

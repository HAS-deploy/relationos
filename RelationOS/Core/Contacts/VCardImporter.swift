import Foundation
import Contacts

/// Parses vCard (.vcf) payloads and maps them to `Contact` rows.
///
/// Reached three ways:
///   * Document picker (`.fileImporter`) selects one or more .vcf files
///   * Share-sheet "Open in RelationOS" hands us a file URL via
///     `RelationOSApp.onOpenURL`
///   * Settings → "Paste vCard text" accepts the raw BEGIN:VCARD blob
///     (helpful when someone emails a vCard inline rather than as
///     an attachment).
///
/// The actual parsing uses `CNContactVCardSerialization`, the same code
/// path the system Contacts app uses, so we get the full property
/// matrix (names, multiple phones / emails, org) for free.
enum VCardImporter {
    enum ImportError: Error {
        case readFailed(Error)
        case parseFailed(Error)
        case empty
    }

    /// Parse a file on disk. Throws on read/parse failure.
    static func parse(fileURL: URL) throws -> [Contact] {
        let needsScope = fileURL.startAccessingSecurityScopedResource()
        defer { if needsScope { fileURL.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: fileURL)
            return try parse(data: data)
        } catch let err as ImportError {
            throw err
        } catch {
            throw ImportError.readFailed(error)
        }
    }

    /// Parse a UTF-8 string (e.g. pasted from email body).
    static func parse(text: String) throws -> [Contact] {
        guard let data = text.data(using: .utf8) else { throw ImportError.empty }
        return try parse(data: data)
    }

    static func parse(data: Data) throws -> [Contact] {
        let cnContacts: [CNContact]
        do {
            cnContacts = try CNContactVCardSerialization.contacts(with: data)
        } catch {
            throw ImportError.parseFailed(error)
        }
        let mapped = cnContacts.compactMap { PhoneContactsImporter.map($0) }
            // vCard ids aren't stable across exports — overwrite the
            // CN-supplied identifier with the vCard UID if present, else
            // leave nil so dedupe falls through to name+email/phone.
            .map { (c: Contact) -> Contact in
                var copy = c
                copy.source = .vcard
                copy.externalId = c.externalId.flatMap { $0.isEmpty ? nil : $0 }
                return copy
            }
        if mapped.isEmpty { throw ImportError.empty }
        return mapped
    }
}

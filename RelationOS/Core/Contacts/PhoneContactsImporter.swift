import Foundation
import Contacts

/// Wraps `CNContactStore` for the two import paths the app exposes:
///
/// 1. **Selective via the system picker** (`CNContactPickerViewController`).
///    No `NSContactsUsageDescription` prompt fires — the picker runs out of
///    process and only hands back the user's chosen rows. This is the
///    privacy-cheapest path; we always offer it.
///
/// 2. **Bulk via `CNContactStore`**. Triggers the usage prompt. We enumerate
///    the full address book, then surface a checkbox list in
///    `ImportFromPhoneView` so the user still confirms what crosses the
///    boundary into RelationOS. Even after granting access we do not
///    auto-sync — every import is an explicit user action.
@MainActor
final class PhoneContactsImporter {
    enum AuthorizationStatus {
        case notDetermined
        case denied
        case restricted
        case authorized
        case limited           // iOS 18+ partial-access mode

        init(_ raw: CNAuthorizationStatus) {
            switch raw {
            case .notDetermined: self = .notDetermined
            case .denied:        self = .denied
            case .restricted:    self = .restricted
            case .authorized:    self = .authorized
            #if compiler(>=6.0)
            case .limited:       self = .limited
            #endif
            @unknown default:    self = .denied
            }
        }
    }

    enum ImportError: Error {
        case permissionDenied
        case fetchFailed(Error)
    }

    static let shared = PhoneContactsImporter()
    private let store = CNContactStore()

    // Pure data — safe to read from any actor (Task.detached enumerates
    // contacts off the main queue, and VCardImporter is non-isolated).
    nonisolated(unsafe) private static let keys: [CNKeyDescriptor] = [
        CNContactGivenNameKey,
        CNContactFamilyNameKey,
        CNContactOrganizationNameKey,
        CNContactPhoneNumbersKey,
        CNContactEmailAddressesKey,
        CNContactIdentifierKey,
    ].map { $0 as CNKeyDescriptor }

    var currentStatus: AuthorizationStatus {
        AuthorizationStatus(CNContactStore.authorizationStatus(for: .contacts))
    }

    /// Trigger the system permission prompt if needed, then return the
    /// resulting authorization status. Safe to call repeatedly.
    func requestAccess() async -> AuthorizationStatus {
        let raw = CNContactStore.authorizationStatus(for: .contacts)
        if raw == .notDetermined {
            do {
                _ = try await store.requestAccess(for: .contacts)
            } catch {
                return .denied
            }
        }
        return AuthorizationStatus(CNContactStore.authorizationStatus(for: .contacts))
    }

    /// Enumerate every contact the user has granted access to (which may
    /// be a partial set under iOS 18 limited access). Off the main thread.
    func fetchAll() async throws -> [Contact] {
        let status = await requestAccess()
        switch status {
        case .denied, .restricted, .notDetermined:
            throw ImportError.permissionDenied
        case .authorized, .limited:
            break
        }
        return try await Task.detached(priority: .userInitiated) { [store = self.store] in
            var rows: [Contact] = []
            let request = CNContactFetchRequest(keysToFetch: Self.keys)
            request.sortOrder = .userDefault
            do {
                try store.enumerateContacts(with: request) { cn, _ in
                    if let c = Self.map(cn) { rows.append(c) }
                }
            } catch {
                throw ImportError.fetchFailed(error)
            }
            return rows
        }.value
    }

    /// Convert a `CNContact` (e.g. the rows returned from
    /// `CNContactPickerViewController`) into our `Contact`. nil if the
    /// row is unusable (no name and no phone/email at all). nonisolated
    /// so VCardImporter / off-main contact enumeration can call it.
    nonisolated static func map(_ cn: CNContact) -> Contact? {
        let first = cn.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = cn.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let org = cn.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = cn.phoneNumbers.first?.value.stringValue
        let email = (cn.emailAddresses.first?.value as String?)

        let composedName: String
        if !first.isEmpty || !last.isEmpty {
            composedName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        } else if !org.isEmpty {
            composedName = org
        } else if let e = email, !e.isEmpty {
            composedName = e
        } else if let p = phone, !p.isEmpty {
            composedName = p
        } else {
            return nil
        }

        return Contact(
            name: composedName,
            phone: phone,
            email: email,
            source: .phone,
            externalId: cn.identifier
        )
    }
}

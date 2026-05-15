import Foundation
import Combine

/// Glue between OAuth + Fetcher + Summarizer + Store.
/// Holds per-contact "is currently syncing" state for the UI.
@MainActor
final class MailCoordinator: ObservableObject {
    enum Status: Equatable {
        case idle
        case syncing
        case summarizing
        case done
        case error(String)
    }

    @Published private(set) var statusByContact: [UUID: Status] = [:]
    let store: EmailStore

    init() {
        self.store = EmailStore()
    }

    init(store: EmailStore) {
        self.store = store
    }

    var isConnected: Bool { MicrosoftMailAuth.isConnected }
    var isMicrosoftConfigured: Bool { MicrosoftMailAuth.isConfigured }

    /// Sync + summarize a single contact. Caller should call this on
    /// "view appear" of ContactDetailView and on a pull-to-refresh. Safe
    /// to invoke when not connected — short-circuits to .idle.
    func syncAndSummarize(_ contact: Contact) async {
        guard MicrosoftMailAuth.isConnected else {
            statusByContact[contact.id] = .idle
            return
        }
        guard (contact.email?.isEmpty == false) else {
            statusByContact[contact.id] = .idle
            return
        }
        statusByContact[contact.id] = .syncing
        do {
            let emails = try await EmailFetcher.shared.fetchRecentEmails(for: contact)
            store.replaceEmails(emails, for: contact.id)
            store.recordSync(success: true)
            statusByContact[contact.id] = .summarizing
            let digest = await EmailSummarizer.shared.summarize(contact: contact, emails: emails)
            store.storeDigest(digest)
            statusByContact[contact.id] = .done
        } catch EmailFetcher.FetcherError.notConnected {
            statusByContact[contact.id] = .error("Reconnect Outlook in Settings — your session expired.")
            store.recordSync(success: false, error: "401 — token expired")
        } catch {
            statusByContact[contact.id] = .error(String(describing: error).prefix(200).description)
            store.recordSync(success: false, error: String(describing: error))
        }
    }

    /// Wipe the cached emails + digests + revoke tokens. Settings → "Disconnect Outlook".
    func disconnect() {
        MicrosoftMailAuth.shared.disconnect()
        store.wipe()
        statusByContact = [:]
    }
}

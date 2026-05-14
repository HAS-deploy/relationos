import SwiftUI
import Contacts
import UniformTypeIdentifiers
import UIKit

struct ContactsListView: View {
    @EnvironmentObject var contacts: ContactsStore
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.analytics) private var analytics

    let onGatedTap: (PremiumFeature) -> Void

    @State private var showAddSheet: Bool = false
    @State private var newContactName: String = ""
    @State private var newContactNotes: String = ""
    @State private var newContactTags: String = ""

    // Import flows
    @State private var showSystemPicker: Bool = false
    @State private var showBulkImport: Bool = false
    @State private var showVCardPicker: Bool = false
    @State private var importBanner: ImportBanner?

    private struct ImportBanner: Identifiable {
        let id = UUID()
        let title: String
        let detail: String?
    }

    private var gate: PremiumGate { PremiumGate(isPremium: purchases.isPremium) }

    var body: some View {
        Group {
            if contacts.contacts.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(contacts.contacts) { contact in
                        NavigationLink(value: contact.id) {
                            ContactRow(contact: contact)
                        }
                    }
                    .onDelete { offsets in contacts.removeContact(at: offsets) }
                }
                .navigationDestination(for: UUID.self) { id in
                    if let c = contacts.contact(id: id) {
                        ContactDetailView(contact: c)
                    }
                }
            }
        }
        .navigationTitle("Contacts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        if gate.canAddAnotherContact(currentCount: contacts.contacts.count) {
                            showAddSheet = true
                        } else {
                            onGatedTap(.unlimitedContacts)
                        }
                    } label: {
                        Label("Add manually", systemImage: "square.and.pencil")
                    }

                    Section("Import") {
                        Button { showSystemPicker = true } label: {
                            Label("Pick from Phone…", systemImage: "person.crop.circle.badge.plus")
                        }
                        Button { showBulkImport = true } label: {
                            Label("Import all from Phone…", systemImage: "person.2.fill")
                        }
                        Button { showVCardPicker = true } label: {
                            Label("Import vCard (.vcf)…", systemImage: "doc.text")
                        }
                        if OAuthContactsImporter.isConfigured(for: .google) {
                            Button { importFromOAuth(.google) } label: {
                                Label("Import from Google…", systemImage: "g.circle")
                            }
                        }
                        if OAuthContactsImporter.isConfigured(for: .microsoft) {
                            Button { importFromOAuth(.microsoft) } label: {
                                Label("Import from Microsoft…", systemImage: "m.circle")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) { addContactSheet }
        .sheet(isPresented: $showBulkImport) { ImportFromPhoneView() }
        .sheet(isPresented: $showSystemPicker) {
            ContactPickerSheet { picked in
                showSystemPicker = false
                guard let picked, !picked.isEmpty else { return }
                let mapped = picked.compactMap { PhoneContactsImporter.map($0) }
                let r = contacts.addContacts(mapped)
                announce(inserted: r.inserted, merged: r.merged, source: "Phone")
            }
        }
        .fileImporter(
            isPresented: $showVCardPicker,
            allowedContentTypes: [UTType.vCard],
            allowsMultipleSelection: true
        ) { result in
            handleVCardFiles(result)
        }
        .alert(item: $importBanner) { banner in
            Alert(
                title: Text(banner.title),
                message: banner.detail.map(Text.init),
                dismissButton: .default(Text("OK"))
            )
        }
        .onOpenURL { url in
            // Share-sheet entry point — someone tapped "Open in RelationOS"
            // on a .vcf attachment in Mail or Messages.
            if url.pathExtension.lowercased() == "vcf" {
                handleVCardFiles(.success([url]))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text("No contacts yet").font(.title3.bold())
            Text("Add someone manually, or import from your phone or a vCard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 12) {
                Button { showSystemPicker = true } label: {
                    Label("Pick contacts", systemImage: "person.crop.circle.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button { showBulkImport = true } label: {
                    Label("Import all", systemImage: "person.2.fill")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)

            if !purchases.isPremium {
                Text("Free tier: up to \(PricingConfig.freeContactCap) contacts.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
    }

    private var addContactSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $newContactName)
                }
                Section("Notes") {
                    TextField("What should you remember about this person?",
                              text: $newContactNotes,
                              axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    TextField("Tags (comma-separated)", text: $newContactTags)
                } footer: {
                    Text("Examples: VC, family, alumni")
                }
            }
            .navigationTitle("New contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        resetAddSheetFields()
                        showAddSheet = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let trimmedName = newContactName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty else { return }
                        let parsedTags = newContactTags
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        let trimmedNotes = newContactNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                        contacts.addContact(Contact(
                            name: trimmedName,
                            notes: trimmedNotes,
                            tags: parsedTags,
                            source: .manual
                        ))
                        analytics.track(.contactAdded)
                        resetAddSheetFields()
                        showAddSheet = false
                    }
                    .disabled(newContactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func resetAddSheetFields() {
        newContactName = ""
        newContactNotes = ""
        newContactTags = ""
    }

    // MARK: - Import helpers

    private func handleVCardFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var inserted = 0, merged = 0, failed = 0
            for url in urls {
                do {
                    let rows = try VCardImporter.parse(fileURL: url)
                    let r = contacts.addContacts(rows)
                    inserted += r.inserted
                    merged += r.merged
                } catch {
                    failed += 1
                }
            }
            announce(inserted: inserted, merged: merged, source: "vCard",
                     extra: failed > 0 ? "\(failed) file(s) failed to parse." : nil)
        case .failure(let err):
            importBanner = ImportBanner(title: "Import failed", detail: err.localizedDescription)
        }
    }

    private func importFromOAuth(_ provider: OAuthContactsImporter.Provider) {
        Task {
            do {
                let anchor = currentWindow()
                let rows = try await OAuthContactsImporter.shared
                    .importContacts(from: provider, anchor: anchor)
                let r = contacts.addContacts(rows)
                let label: String = (provider == .google) ? "Google" : "Microsoft"
                announce(inserted: r.inserted, merged: r.merged, source: label)
            } catch OAuthContactsImporter.OAuthError.userCancelled {
                return
            } catch OAuthContactsImporter.OAuthError.notConfigured {
                importBanner = ImportBanner(
                    title: "Not configured",
                    detail: "Add the OAuth client ID for this provider in Info.plist to enable."
                )
            } catch {
                importBanner = ImportBanner(
                    title: "Import failed",
                    detail: String(describing: error)
                )
            }
        }
    }

    @MainActor
    private func currentWindow() -> UIWindow {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }

    private func announce(inserted: Int, merged: Int, source: String, extra: String? = nil) {
        let parts = [
            inserted > 0 ? "Added \(inserted)" : nil,
            merged > 0 ? "updated \(merged)" : nil,
        ].compactMap { $0 }
        let title = parts.isEmpty ? "Nothing new from \(source)" : "\(parts.joined(separator: ", ")) from \(source)"
        let detail = [extra].compactMap { $0 }.joined(separator: " ")
        importBanner = ImportBanner(title: title, detail: detail.isEmpty ? nil : detail)
        analytics.track(.contactAdded, properties: [
            "source": source.lowercased(),
            "inserted": String(inserted),
            "merged": String(merged),
        ])
    }
}

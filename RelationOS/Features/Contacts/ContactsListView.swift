import SwiftUI

struct ContactsListView: View {
    @EnvironmentObject var contacts: ContactsStore
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.analytics) private var analytics

    let onGatedTap: (PremiumFeature) -> Void

    @State private var showAddSheet: Bool = false
    @State private var newContactName: String = ""
    @State private var newContactNotes: String = ""
    @State private var newContactTags: String = ""

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
                Button {
                    if gate.canAddAnotherContact(currentCount: contacts.contacts.count) {
                        showAddSheet = true
                    } else {
                        onGatedTap(.unlimitedContacts)
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            addContactSheet
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text("No contacts yet").font(.title3.bold())
            Text("Tap + to add the first person you want to remember.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
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
                            tags: parsedTags
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
}

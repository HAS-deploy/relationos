import SwiftUI

struct ContactDetailView: View {
    @EnvironmentObject var contacts: ContactsStore
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.reminders) private var reminderManager
    @Environment(\.analytics) private var analytics

    @State private var workingContact: Contact
    @State private var newTag: String = ""
    @State private var showAddReminder: Bool = false
    @State private var newReminderTitle: String = ""
    @State private var newReminderDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var showPaywall: PremiumFeature?
    @State private var showLogSheet: Bool = false

    init(contact: Contact) {
        _workingContact = State(initialValue: contact)
    }

    var body: some View {
        Form {
            contactInfoSection
            notesSection
            tagsSection
            interactionSection
            remindersSection
        }
        .navigationTitle(workingContact.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: workingContact) { newValue in
            contacts.updateContact(newValue)
        }
        .sheet(isPresented: $showAddReminder) {
            addReminderSheet
        }
        .sheet(isPresented: $showLogSheet) {
            LogInteractionSheet(contact: workingContact)
                .environmentObject(contacts)
        }
        .sheet(item: $showPaywall) { feature in
            PaywallView(triggeringFeature: feature)
                .environmentObject(purchases)
        }
    }

    @ViewBuilder
    private var contactInfoSection: some View {
        let phone = workingContact.phone ?? ""
        let email = workingContact.email ?? ""
        if !phone.isEmpty || !email.isEmpty || workingContact.source != nil {
            Section("Contact") {
                if !phone.isEmpty {
                    HStack {
                        Image(systemName: "phone.fill").foregroundStyle(.secondary)
                        Text(phone)
                        Spacer()
                    }
                }
                if !email.isEmpty {
                    HStack {
                        Image(systemName: "envelope.fill").foregroundStyle(.secondary)
                        Text(email)
                        Spacer()
                    }
                }
                if let src = workingContact.source, src != .manual {
                    Text("Imported from \(src.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $workingContact.notes)
                .frame(minHeight: 120)
        }
    }

    private var tagsSection: some View {
        Section {
            if workingContact.tags.isEmpty {
                Text("No tags yet").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(workingContact.tags, id: \.self) { tag in
                    HStack {
                        Text("#\(tag)")
                        Spacer()
                        Button(role: .destructive) {
                            workingContact.tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                TextField("Add tag", text: $newTag)
                Button("Add") {
                    let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    workingContact.tags.append(trimmed)
                    newTag = ""
                }
                .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("Tags")
        }
    }

    private var interactionSection: some View {
        Section("Last interaction") {
            if let last = workingContact.lastInteractedAt {
                Text(last.formatted(date: .abbreviated, time: .shortened))
            } else {
                Text("Not yet logged").foregroundStyle(.secondary)
            }
            Button {
                showLogSheet = true
            } label: {
                Label("Log call, text, or email", systemImage: "phone.arrow.up.right")
            }
            Button("Mark touched now") {
                workingContact.lastInteractedAt = Date()
                contacts.touchInteraction(contactId: workingContact.id)
            }
        }
    }

    private var remindersSection: some View {
        Section("Reminders") {
            let mine = contacts.remindersFor(contactId: workingContact.id)
            if mine.isEmpty {
                Text("No reminders yet").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(mine) { r in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title)
                        Text(r.fireAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Button {
                showAddReminder = true
            } label: {
                Label("Add reminder", systemImage: "bell.badge.fill")
            }
        }
    }

    private var addReminderSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $newReminderTitle)
                    DatePicker("When", selection: $newReminderDate)
                } footer: {
                    Text("Reminders fire as iOS notifications. The first reminder you add will trigger a one-time permission prompt. If you decline, the reminder is still saved — you can enable notifications later in iOS Settings → RelationOS.")
                }
            }
            .navigationTitle("New reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        newReminderTitle = ""
                        showAddReminder = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { addReminder() }
                        .disabled(newReminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func addReminder() {
        let trimmed = newReminderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let reminder = Reminder(
            contactId: workingContact.id,
            title: trimmed,
            fireAt: newReminderDate
        )
        contacts.upsertReminder(reminder)
        analytics.track(.reminderEnabled, properties: ["kind": "contact"])

        // Schedule a local notification. Reminder count rides under the
        // free-tier contact cap; Pro subscribers can hold reminders for
        // contacts beyond the 100-contact free limit.
        Task {
            let status = await reminderManager.currentStatus()
            if status == .notDetermined {
                _ = await reminderManager.requestAuthorization()
            }
            try? await reminderManager.scheduleOneShotReminder(
                identifier: "reminder.\(reminder.id.uuidString)",
                title: reminder.title,
                body: "Reminder about \(workingContact.name)",
                fireAt: reminder.fireAt
            )
        }

        newReminderTitle = ""
        showAddReminder = false
    }
}

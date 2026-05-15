import SwiftUI
import UIKit

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
    @State private var notificationAuthStatus: ReminderManager.AuthStatus = .notDetermined
    @State private var showNotificationPrePrompt: Bool = false
    @State private var reminderAddedTrigger: Int = 0
    @State private var markedTouchedTrigger: Int = 0
    @AppStorage("relationos.reminders.preprompt_shown") private var prePromptShown: Bool = false

    init(contact: Contact) {
        _workingContact = State(initialValue: contact)
    }

    var body: some View {
        Form {
            contactInfoSection
            ContactEmailsSection(contact: workingContact)
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
        .task {
            notificationAuthStatus = await reminderManager.currentStatus()
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
        .sheet(isPresented: $showNotificationPrePrompt) {
            notificationPrePromptSheet
        }
        .hapticSuccess(trigger: reminderAddedTrigger)
        .hapticSuccess(trigger: markedTouchedTrigger)
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
                markedTouchedTrigger &+= 1
            }
        }
    }

    private var remindersSection: some View {
        Section {
            let mine = contacts.remindersFor(contactId: workingContact.id)
            if notificationAuthStatus == .denied && !mine.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "bell.slash.fill")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications off")
                            .font(.subheadline.bold())
                        Text("Reminders are saved but won't alert you. Enable notifications in iOS Settings → RelationOS.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            Link("Open Settings", destination: url)
                                .font(.caption.bold())
                        }
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
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
                presentAddReminder()
            } label: {
                Label("Add reminder", systemImage: "bell.badge.fill")
            }
            .accessibilityHint("Schedules a local notification about this contact.")
        } header: {
            Text("Reminders")
        }
    }

    /// Tap path for the "Add reminder" button. If notifications have never
    /// been requested AND the pre-prompt explainer has not been shown,
    /// show the explainer first — gives the user context before iOS's
    /// one-shot system prompt. Otherwise (already determined, or
    /// explainer dismissed once) go straight to the add-reminder sheet.
    private func presentAddReminder() {
        if notificationAuthStatus == .notDetermined && !prePromptShown {
            showNotificationPrePrompt = true
        } else {
            showAddReminder = true
        }
    }

    private var notificationPrePromptSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                Text("Allow reminders?")
                    .font(.title2.bold())
                Text("RelationOS uses local notifications to remind you to follow up with contacts. Notifications stay on your device — nothing is sent to a server.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("iOS will ask once. If you decline, you can enable notifications later in Settings → RelationOS, but iOS won't ask again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    prePromptShown = true
                    showNotificationPrePrompt = false
                    Task {
                        _ = await reminderManager.requestAuthorization()
                        notificationAuthStatus = await reminderManager.currentStatus()
                        // Now open the actual reminder sheet so the user
                        // can finish the action they originally tapped.
                        showAddReminder = true
                    }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                Button("Not now") {
                    prePromptShown = true
                    showNotificationPrePrompt = false
                    // User declined the explainer — still let them save
                    // the reminder locally. They can revisit notifications
                    // later via iOS Settings.
                    showAddReminder = true
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { showNotificationPrePrompt = false }
                }
            }
        }
    }

    private var addReminderSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $newReminderTitle)
                    // Past dates would be silently dropped by
                    // UNCalendarNotificationTrigger; constrain to the
                    // future so the date picker can't pick a no-op.
                    DatePicker("When", selection: $newReminderDate, in: Date()...)
                } footer: {
                    if notificationAuthStatus == .denied {
                        Text("Notifications are off — your reminder is saved but iOS won't alert you. Enable in iOS Settings → RelationOS.")
                            .foregroundStyle(.orange)
                    } else {
                        Text("Reminders fire as iOS notifications stored on your device. If you decline the permission prompt, the reminder is still saved — you can enable notifications later in iOS Settings → RelationOS.")
                    }
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
        reminderAddedTrigger &+= 1

        // Schedule a local notification. Reminder count rides under the
        // free-tier contact cap; Pro subscribers can hold reminders for
        // contacts beyond the 100-contact free limit. We do NOT request
        // authorization inline here — the pre-prompt path triggered from
        // `presentAddReminder()` already handled that with explainer
        // context. If permission was denied, the reminder still persists
        // and the denied-state banner in the reminders section will
        // surface the recovery path.
        Task {
            // Refresh status in case the user just answered the system
            // prompt from the pre-prompt sheet.
            notificationAuthStatus = await reminderManager.currentStatus()
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

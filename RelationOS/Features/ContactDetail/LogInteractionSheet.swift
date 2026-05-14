import SwiftUI
import MessageUI
import UIKit

/// The user-facing substitute for the things iOS won't expose:
/// inbound SMS, call history, and email content. Each button either
/// opens the native compose sheet (and records what we sent), or
/// records a manual "I already talked to them" entry.
///
/// The Manual section is what makes this useful for back-filling
/// older interactions and for in-person conversations that have no
/// other digital footprint.
struct LogInteractionSheet: View {
    @EnvironmentObject var contacts: ContactsStore
    @Environment(\.dismiss) private var dismiss

    let contact: Contact

    @State private var manualKind: Interaction.Kind = .call
    @State private var manualWhen: Date = Date()
    @State private var manualNotes: String = ""

    @State private var showMail = false
    @State private var showMessage = false
    @State private var smsBody: String = ""
    @State private var mailSubject: String = ""
    @State private var mailBody: String = ""

    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                quickLogSection
                manualLogSection
                errorSectionIfAny
                historySectionIfAny
            }
            .navigationTitle("Log interaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showMessage) { messageSheet }
            .sheet(isPresented: $showMail) { mailSheet }
        }
    }

    // MARK: - Sections

    private var quickLogSection: some View {
        Section {
            Button { startCall() } label: {
                Label("Call \(contact.phone ?? "—")", systemImage: "phone.fill")
            }
            .disabled((contact.phone ?? "").isEmpty)

            Button { showMessage = true } label: {
                Label("Text", systemImage: "message.fill")
            }
            .disabled((contact.phone ?? "").isEmpty || !MessageComposeView.canSend)

            Button { showMail = true } label: {
                Label("Email", systemImage: "envelope.fill")
            }
            .disabled((contact.email ?? "").isEmpty || !MailComposeView.canSend)
        } header: {
            Text("Quick log")
        } footer: {
            Text("iOS doesn't share call, text, or inbox history with third-party apps. Quick-log opens the system composer and records what you send.")
        }
    }

    private var manualLogSection: some View {
        Section {
            Picker("Kind", selection: $manualKind) {
                Text("Call").tag(Interaction.Kind.call)
                Text("Text").tag(Interaction.Kind.text)
                Text("Email").tag(Interaction.Kind.email)
                Text("In person").tag(Interaction.Kind.meeting)
                Text("Other").tag(Interaction.Kind.other)
            }
            DatePicker("When", selection: $manualWhen)
            TextField("Notes (optional)", text: $manualNotes, axis: .vertical)
                .lineLimit(2...6)
            Button("Log it") { logManual() }
                .buttonStyle(.borderedProminent)
        } header: {
            Text("Manual log")
        }
    }

    @ViewBuilder
    private var errorSectionIfAny: some View {
        if let err = error {
            Section {
                Text(err).foregroundStyle(.red).font(.caption)
            }
        }
    }

    @ViewBuilder
    private var historySectionIfAny: some View {
        let history = contacts.interactionsFor(contactId: contact.id)
        if !history.isEmpty {
            Section {
                ForEach(history) { i in
                    interactionRow(i)
                }
            } header: {
                Text("History")
            }
        }
    }

    private func interactionRow(_ i: Interaction) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: icon(for: i.kind))
                Text(i.kind.rawValue.capitalized)
                Spacer()
                Text(i.occurredAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !i.notes.isEmpty {
                Text(i.notes).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Compose sheet payloads

    private var messageSheet: some View {
        MessageComposeView(
            recipients: [contact.phone ?? ""],
            body: smsBody
        ) { result in
            if result == .sent {
                record(kind: .text, via: .composer, notes: smsBody)
            }
            showMessage = false
        }
    }

    private var mailSheet: some View {
        MailComposeView(
            to: [contact.email ?? ""],
            subject: mailSubject,
            body: mailBody
        ) { result in
            if result == .sent {
                record(kind: .email, via: .composer,
                       notes: mailSubject.isEmpty ? mailBody : mailSubject)
            }
            showMail = false
        }
    }

    // MARK: - Actions

    private func icon(for kind: Interaction.Kind) -> String {
        switch kind {
        case .call:    return "phone.fill"
        case .text:    return "message.fill"
        case .email:   return "envelope.fill"
        case .meeting: return "person.2.fill"
        case .other:   return "circle.fill"
        }
    }

    private func startCall() {
        guard let raw = contact.phone, !raw.isEmpty,
              let url = URL(string: "tel://\(raw.filter { $0.isNumber || $0 == "+" })"),
              UIApplication.shared.canOpenURL(url) else {
            error = "Can't place a call to that number."
            return
        }
        // iOS leaves us once we open `tel:` — record the intent so
        // history shows we tried, even though we can't know if the
        // call connected. The CallObserver-driven nudge handles the
        // connected case separately.
        record(kind: .call, via: .composer, notes: "")
        UIApplication.shared.open(url)
    }

    private func logManual() {
        let trimmed = manualNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        record(kind: manualKind, via: .manual, occurredAt: manualWhen, notes: trimmed)
        manualNotes = ""
        manualWhen = Date()
    }

    private func record(kind: Interaction.Kind,
                        via: Interaction.Via,
                        occurredAt: Date = Date(),
                        notes: String) {
        let interaction = Interaction(
            contactId: contact.id,
            kind: kind,
            via: via,
            occurredAt: occurredAt,
            notes: notes
        )
        contacts.logInteraction(interaction)
    }
}

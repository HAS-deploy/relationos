import SwiftUI
import UIKit

/// Bulk-import flow: requests Contacts access, fetches the full
/// address book, then lets the user select which rows actually cross
/// into RelationOS. Even after granting access we never auto-sync —
/// every import is an explicit user action with a confirm step. This
/// matches what App Review expects of "Contacts access" apps that
/// aren't dialers.

fileprivate struct ImportRow: Identifiable, Hashable {
    var id: String { contact.externalId ?? contact.id.uuidString }
    var contact: Contact
    var selected: Bool
}

fileprivate enum ImportPhase {
    case loading
    case denied
    case ready
    case importing
    case done
}

struct ImportFromPhoneView: View {
    @EnvironmentObject var contacts: ContactsStore
    @Environment(\.dismiss) private var dismiss

    @State private var phase: ImportPhase = .loading
    @State private var rows: [ImportRow] = []
    @State private var search: String = ""
    @State private var selectAll: Bool = true
    @State private var result: (inserted: Int, merged: Int)?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Import from Phone")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if phase == .ready {
                            Button("Import") { runImport() }
                                .disabled(!rows.contains(where: \.selected))
                        }
                    }
                }
                .task(load)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView("Reading your address book…")
                .padding()
        case .denied:
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.secondary)
                Text("Contacts access is off").font(.title3.bold())
                Text("Enable RelationOS in iOS Settings → Privacy & Security → Contacts to import. Or use the system picker, which doesn't need this permission.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        case .ready:
            List {
                Section {
                    Toggle("Select all (\(filtered.count))", isOn: $selectAll)
                        .onChange(of: selectAll) { newValue in
                            for i in rows.indices where rowMatches(rows[i]) {
                                rows[i].selected = newValue
                            }
                        }
                }
                Section {
                    ForEach(filtered) { row in
                        ImportRowCell(row: row, onToggle: { toggle(row.id) })
                    }
                } footer: {
                    Text("Already-imported contacts will be updated, not duplicated. Notes and tags you've added stay yours.")
                }
            }
            .searchable(text: $search, prompt: "Search name, phone, or email")
        case .importing:
            ProgressView("Importing…").padding()
        case .done:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.green)
                if let r = result {
                    Text("Added \(r.inserted)").font(.title3.bold())
                    if r.merged > 0 {
                        Text("Updated \(r.merged) existing").foregroundStyle(.secondary)
                    }
                }
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private var filtered: [ImportRow] {
        guard !search.isEmpty else { return rows }
        let needle = search.lowercased()
        return rows.filter { rowMatches($0, needle: needle) }
    }

    private func rowMatches(_ row: ImportRow, needle: String? = nil) -> Bool {
        let q = needle ?? search.lowercased()
        if q.isEmpty { return true }
        if row.contact.name.lowercased().contains(q) { return true }
        if (row.contact.email ?? "").lowercased().contains(q) { return true }
        if (row.contact.phone ?? "").contains(q) { return true }
        return false
    }

    private func toggle(_ id: String) {
        guard let idx = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[idx].selected.toggle()
    }

    @Sendable
    private func load() async {
        do {
            let fetched = try await PhoneContactsImporter.shared.fetchAll()
            await MainActor.run {
                self.rows = fetched.map { ImportRow(contact: $0, selected: true) }
                self.phase = .ready
            }
        } catch PhoneContactsImporter.ImportError.permissionDenied {
            await MainActor.run { self.phase = .denied }
        } catch {
            await MainActor.run { self.phase = .denied }
        }
    }

    private func runImport() {
        phase = .importing
        let picked = rows.filter(\.selected).map(\.contact)
        let r = contacts.addContacts(picked)
        result = r
        phase = .done
    }
}

fileprivate struct ImportRowCell: View {
    let row: ImportRow
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: row.selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(row.selected ? Theme.accent : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.contact.name).foregroundStyle(.primary)
                    if let line = subtitle {
                        Text(line).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String? {
        if let p = row.contact.phone, let e = row.contact.email, !p.isEmpty, !e.isEmpty {
            return "\(p) · \(e)"
        }
        if let p = row.contact.phone, !p.isEmpty { return p }
        if let e = row.contact.email, !e.isEmpty { return e }
        return nil
    }
}

import SwiftUI

struct ContactRow: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(initials(from: contact.name))
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name).font(.body)
                Text(lastTouchedLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(contact.name), \(lastTouchedLabel)")
    }

    private var lastTouchedLabel: String {
        guard let last = contact.lastInteractedAt else {
            return "Not yet touched"
        }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return "Last touched " + f.localizedString(for: last, relativeTo: Date())
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let initials = parts.compactMap { $0.first }.map { String($0) }.joined()
        return initials.isEmpty ? "?" : initials.uppercased()
    }
}

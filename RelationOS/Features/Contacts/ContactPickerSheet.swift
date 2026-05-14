import SwiftUI
import ContactsUI
import Contacts
import UIKit

/// Wraps `CNContactPickerViewController` as a SwiftUI sheet. The
/// picker runs out-of-process under the system Contacts entitlement,
/// so it never triggers the `NSContactsUsageDescription` prompt and
/// the user can hand-select exactly the rows they want imported.
/// This is the privacy-cheapest import path and the default we surface
/// in the Import menu.
struct ContactPickerSheet: UIViewControllerRepresentable {
    /// nil means the user cancelled; an empty array can't happen because
    /// the picker requires at least one selection before "Done" enables.
    let onPicked: ([CNContact]?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let vc = CNContactPickerViewController()
        vc.delegate = context.coordinator
        // Restrict the displayed properties to what we'll actually
        // import — avoids the picker showing photos / birthdays that
        // we don't carry through.
        vc.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
        ]
        return vc
    }

    func updateUIViewController(_ controller: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPicked: ([CNContact]?) -> Void
        init(onPicked: @escaping ([CNContact]?) -> Void) { self.onPicked = onPicked }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onPicked(nil)
        }

        // Multi-select path
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            onPicked(contacts)
        }

        // Single-select path (when the picker is presented without
        // setting `predicateForSelectionOfContact`). We forward either
        // signal to the same handler.
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onPicked([contact])
        }
    }
}

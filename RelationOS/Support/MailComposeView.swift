import SwiftUI
import MessageUI
import UIKit

/// SwiftUI wrapper over `MFMailComposeViewController`. This is the
/// only legal way for a third-party app to put an email in front of
/// the user — Apple does not allow reading or programmatic sending
/// of mail without user confirmation.
///
/// Caller decides what to do with the dismiss result via `onResult`,
/// then sets `isPresented = false`. If the device has no Mail account
/// configured, `MailComposeView.canSend` returns false; callers should
/// branch on that and fall back to `mailto:` URL open.
struct MailComposeView: UIViewControllerRepresentable {
    static var canSend: Bool { MFMailComposeViewController.canSendMail() }

    let to: [String]
    let subject: String
    let body: String
    let onResult: (MFMailComposeResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(to)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onResult: (MFMailComposeResult) -> Void
        init(onResult: @escaping (MFMailComposeResult) -> Void) { self.onResult = onResult }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            onResult(result)
            controller.dismiss(animated: true)
        }
    }
}

import SwiftUI
import MessageUI
import UIKit

/// SwiftUI wrapper over `MFMessageComposeViewController` for SMS / iMessage.
/// Same Apple ground rules as MailComposeView: third-party apps can only
/// open the compose sheet, not send programmatically.
struct MessageComposeView: UIViewControllerRepresentable {
    static var canSend: Bool { MFMessageComposeViewController.canSendText() }

    let recipients: [String]
    let body: String
    let onResult: (MessageComposeResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = recipients
        vc.body = body
        return vc
    }

    func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onResult: (MessageComposeResult) -> Void
        init(onResult: @escaping (MessageComposeResult) -> Void) { self.onResult = onResult }
        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            onResult(result)
            controller.dismiss(animated: true)
        }
    }
}

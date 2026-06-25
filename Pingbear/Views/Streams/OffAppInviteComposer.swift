import SwiftUI
import MessageUI

// MARK: - OffAppInviteComposer
struct OffAppInviteComposer: UIViewControllerRepresentable {

    let recipients: [String]
    let body:       String
    let onFinish:   (MessageComposeResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc        = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body       = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let parent: OffAppInviteComposer
        init(_ parent: OffAppInviteComposer) { self.parent = parent }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) { self.parent.onFinish(result) }
        }
    }
}

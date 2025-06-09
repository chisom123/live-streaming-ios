import SwiftUI
import MessageUI

struct CustomShareSheet: View {
    let shareText: String
    let shareLink: String
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingMessageComposer = false
    @State private var linkCopied = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - styled like EditCompetitionView
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("Share Competition Link")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
                
                Color.clear
                    .frame(width: 27, height: 27)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(hex: "#1A2245"))
            
            // Share options
            VStack(spacing: 25) {
                // iMessage
                Button(action: {
                    isShowingMessageComposer = true
                }) {
                    HStack(spacing: 15) {
                        Image(systemName: "message.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.green)
                            .clipShape(Circle())
                        
                        Text("Share via iMessage")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(hex: "#D3D3D3"))
                            .font(.system(size: 15, weight: .bold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(10)
                }
                
                // Copy Link
                Button(action: {
                    UIPasteboard.general.string = shareLink
                    linkCopied = true
                    
                    // Provide haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    Analytics.shared.trackTap(
                        elementId: "copied_link_from_custom_sheet",
                        screenName: "create_competition_share"
                    )
                    // Auto-hide the notification after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        linkCopied = false
                    }
                }) {
                    HStack(spacing: 15) {
                        Image(systemName: linkCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(linkCopied ? Color(hex: "#25D366") : .white)
                            .padding(8)
                            .background(linkCopied ? Color(hex: "#25D366").opacity(0.2) : Color.gray)
                            .clipShape(Circle())
                        
                        Text(linkCopied ? "Link Copied" : "Copy Link")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if !linkCopied {
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color(hex: "#D3D3D3"))
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(Color(hex: "#1A2245"))
                    .cornerRadius(10)
                    .animation(.easeInOut(duration: 0.2), value: linkCopied)
                }
                
                // Show copied notification
                if linkCopied {
                    HStack {
                        Spacer()
                        Text("Link copied to clipboard")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    .padding(.top, 10)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: linkCopied)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            
            Spacer()
        }
        .background(Color(hex: "#10183C"))
        .accentColor(.white)
        .ignoresSafeArea()
        .sheet(isPresented: $isShowingMessageComposer) {
            MessageComposer(message: shareText, isShowing: $isShowingMessageComposer)
        }
    }
}

// MessageComposer for iMessage integration
struct MessageComposer: UIViewControllerRepresentable {
    let message: String
    @Binding var isShowing: Bool
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let composeVC = MFMessageComposeViewController()
        composeVC.body = message
        composeVC.messageComposeDelegate = context.coordinator
        return composeVC
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: MessageComposer
        
        init(_ parent: MessageComposer) {
            self.parent = parent
        }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            // Dismiss the message composer
            controller.dismiss(animated: true) {
                self.parent.isShowing = false
                
                // Track analytics for iMessage sharing
                Analytics.shared.trackTap(
                    elementId: "share_via_imessage",
                    screenName: "create_competition_share"
                )
            }
        }
        
        private func resultString(from result: MessageComposeResult) -> String {
            switch result {
            case .cancelled:
                return "cancelled"
            case .failed:
                return "failed"
            case .sent:
                return "sent"
            @unknown default:
                return "unknown"
            }
        }
    }
}

// Extension to check if messaging is available
extension MessageComposer {
    static var canSendText: Bool {
        MFMessageComposeViewController.canSendText()
    }
}

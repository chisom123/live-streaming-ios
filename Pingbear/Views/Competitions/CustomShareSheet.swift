import SwiftUI
import MessageUI

struct CustomShareSheet: View {
    let shareText: String
    let shareLink: String
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingMessageComposer = false
    @State private var linkCopied = false
    @State private var showInstagramAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27)
                        .foregroundColor(AppTheme.iconColor)
                }
                Spacer()
                Text("Share Invite Link")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(AppTheme.primaryText)
                Spacer()
                Color.clear.frame(width: 27, height: 27)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(AppTheme.cardBackground)
            
            VStack(spacing: 25) {
                Button(action: { isShowingMessageComposer = true }) {
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
                            .foregroundColor(AppTheme.primaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppTheme.secondaryText)
                            .font(.system(size: 15, weight: .bold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    UIPasteboard.general.string = shareLink
                    linkCopied = true
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    Analytics.shared.trackTap(elementId: "copied_link_from_custom_sheet", screenName: "create_competition_share")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { linkCopied = false }
                }) {
                    HStack(spacing: 15) {
                        Image(systemName: "doc.on.doc.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(linkCopied ? AppTheme.green : AppTheme.primaryText)
                            .padding(8)
                            .background(linkCopied ? AppTheme.green.opacity(0.2) : AppTheme.cardHighlight)
                            .clipShape(Circle())
                        Text(linkCopied ? "Link Copied" : "Copy Link")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.primaryText)
                        Spacer()
                        if !linkCopied {
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppTheme.secondaryText)
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(10)
                    .animation(.easeInOut(duration: 0.2), value: linkCopied)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            
            Spacer()
        }
        .background(AppTheme.pageBackground)
        .ignoresSafeArea()
        .sheet(isPresented: $isShowingMessageComposer) {
            MessageComposer(message: shareText, isShowing: $isShowingMessageComposer)
        }
        .alert("Instagram Not Installed", isPresented: $showInstagramAlert) {
            Button("OK", role: .cancel) { }
        }
    }
    
    private func shareToInstagramDM() {
        let encodedText = (shareText).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let instagramURL = URL(string: "instagram://sharesheet?text=\(encodedText)")
        if let url = instagramURL, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    Analytics.shared.trackTap(elementId: "share_via_instagram_dm", screenName: "create_competition_share")
                }
            }
        } else {
            showInstagramAlert = true
            Analytics.shared.trackTap(elementId: "instagram_not_installed", screenName: "create_competition_share")
        }
    }
}

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
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: MessageComposer
        init(_ parent: MessageComposer) { self.parent = parent }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) {
                self.parent.isShowing = false
                Analytics.shared.trackTap(elementId: "share_via_imessage", screenName: "create_competition_share")
            }
        }
    }
}

extension MessageComposer {
    static var canSendText: Bool { MFMessageComposeViewController.canSendText() }
}

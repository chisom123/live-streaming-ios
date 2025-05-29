import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import MessageUI

struct CreateCompetitionShareView: View {
    let competitionName: String
    @State private var isCreating = false
    @State private var competitionId: String?
    @State private var shareLink: String = ""
    @State private var navigateToAddPlayers = false
    @State private var linkCopied = false
    @State private var isCustomShareSheetPresented = false
    @State private var showCompetitionDetails = false
    @State private var competition: Competition?
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Color.clear
                        .frame(width: 27, height: 27)
                    
                    Spacer()
                    
                    Text("Share Competition")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 27, height: 27)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                // Progress indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color(hex: "#FF4081"))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                .padding(.bottom, 30)
                
                // Main content
                if isCreating {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Spacer()
                } else if !shareLink.isEmpty {
                    VStack(spacing: 0) {
                        
                        Text("Share Competition Link")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.bottom, 12)
                        
                        Text("Share this link to invite friends")
                            .font(.system(size: 16, weight: .medium))
                            .lineSpacing(4)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 30)
                        
                        // Share link with copy functionality
                        VStack(spacing: 15) {
                            Button(action: {
                                UIPasteboard.general.string = shareLink
                                linkCopied = true
                                Analytics.shared.trackTap(
                                    elementId: "copied_link",
                                    screenName: "create_competition_share"
                                )
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    linkCopied = false
                                }
                            }) {
                                HStack {
                                    Text(shareLink)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Color(hex: "#FFF"))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                    
                                    Image(systemName: linkCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                        .foregroundColor(linkCopied ? Color(hex: "#25D366") : .white.opacity(0.9))
                                        .font(.system(size: 20))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 15)
                                .frame(maxWidth: .infinity)
                                .background(Color(hex: "#1A2245"))
                                .cornerRadius(15)
                            }
                            
                            if linkCopied {
                                Text("Link Copied!")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 5)
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Share buttons
                        VStack {
                            Button(action: {
                                isCustomShareSheetPresented = true
                                Analytics.shared.trackTap(
                                    elementId: "invite_share_sheet",
                                    screenName: "create_competition_share"
                                )
                            }) {
                                HStack(spacing: 8) {
                                    Text("Share Link")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(Color(hex: "#FFF"))
                                    
                                    Image(systemName: "arrowshape.turn.up.right.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18)
                                        .foregroundColor(Color(hex: "#FFF"))
                                }
                                .padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                .background(Color(hex: "#FF4081"))
                                .cornerRadius(200)
                            }
                            .sheet(isPresented: $isCustomShareSheetPresented) {
                                CustomShareSheet(shareText: createShareText(), shareLink: shareLink)
                            }
                        }
                        .padding(.top, 30)
                        
                        Spacer()
                        
                        // Action buttons
                        VStack(spacing: 15) {
                            Button(action: {
                                navigateToAddPlayers = true
                            }) {
                                Text("Add Friends Manually")
                                    .font(.system(size: 18, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color(hex: "#FF4081"))
                                    .foregroundColor(.white)
                                    .cornerRadius(50)
                            }
                            
                            Button(action: {
                                showCompetitionDetails = true
                            }) {
                                Text("Go to Competition")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(hex: "#FFF"))
                                    .padding(.top, 10)
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .background(Color(hex: "#10183C"))
        .onAppear {
            createCompetition()
            Analytics.shared.trackScreen(name: "create_competition_share")
        }
        .fullScreenCover(isPresented: $navigateToAddPlayers) {
            if let competitionId = competitionId,
               let competition = competition {
                CreateCompetitionAddPlayersView(
                    competitionId: competitionId,
                    competitionName: competitionName,
                    competitionDate: competition.date
                )
            }
        }
        .fullScreenCover(isPresented: $showCompetitionDetails) {
            if let competition = competition {
                CompDetails(competition: competition)
            }
        }
    }
    
    private func createShareText() -> String {
        return "Join my competition \(competitionName) on SocialStar! \(shareLink)"
    }
    
    private func createCompetition() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        isCreating = true
        
        let db = Firestore.firestore()
        let competitionRef = db.collection("competitions").document()
        let newCompetitionId = competitionRef.documentID
        let timestamp = Timestamp()
        let creationDate = timestamp.dateValue()  // Convert to Date for Competition object
        
        // First establish membership
        let creatorMemberRef = competitionRef.collection("members").document(userID)
        
        creatorMemberRef.setData(["userId": userID]) { error in
            if let error = error {
                print("Failed to add creator as member: \(error.localizedDescription)")
                self.isCreating = false
                return
            }
            
            // Create the competition
            let competitionData: [String: Any] = [
                "id": newCompetitionId,
                "description": competitionName,
                "timestamp": timestamp,
                "hostId": userID
            ]
            
            competitionRef.setData(competitionData) { error in
                if let error = error {
                    print("Failed to create competition: \(error.localizedDescription)")
                    self.isCreating = false
                    return
                }
                
                // Add to creator's groupMemberships
                let creatorGroupMembershipRef = db.collection("groupMemberships").document(userID)
                                                 .collection("competitions").document(newCompetitionId)
                creatorGroupMembershipRef.setData(["competitionId": newCompetitionId]) { error in
                    if let error = error {
                        print("Failed to add group membership: \(error.localizedDescription)")
                    }
                    
                    self.isCreating = false
                    self.competitionId = newCompetitionId
                    self.shareLink = DeepLinkHandler.shared.createShareableLink(for: newCompetitionId)
                    
                    // Create Competition object
                    self.competition = Competition(
                        id: newCompetitionId,
                        description: competitionName,
                        date: creationDate
                    )
                    
                    Analytics.shared.trackCompetition(
                        action: "create",
                        competitionId: newCompetitionId
                    )
                }
            }
        }
    }
}

// Custom Share Sheet View
struct CustomShareSheet: View {
    let shareText: String
    let shareLink: String
    @Environment(\.presentationMode) var presentationMode
    @State private var isShowingMessageComposer = false
    @State private var linkCopied = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - styled like EditCompetitionView
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
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

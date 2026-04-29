import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct HowToWinView: View {
    var isWebUser: Bool = false
    var onContinue: () -> Void

    @State private var isCreatingCompetition = false
    @State private var creationError: String? = nil
    @State private var newCompetitionId: String? = nil
    @State private var navigateToPlayers = false

    var body: some View {
        ZStack {
            Color(hex: "#10183C")
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Photo competitions with friends")
                    .font(.system(size: 35, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 60)

                HStack {
                    HStack(spacing: 8) {
                        Text("Win More Points")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Image("gem")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 26, height: 26)
                    }
                    .padding(EdgeInsets(top: 5, leading: 15, bottom: 5, trailing: 15))
                    .background(Color(hex: "#6A5ACD"))
                    .cornerRadius(200)

                    Spacer()
                }
                .padding(.horizontal, 24)

                CompetitionAnimationView()
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                Spacer()

                if let error = creationError {
                    Text(error)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#FF6B6B"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button(action: handleContinue) {
                    if isCreatingCompetition {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color(hex: "#4169E1"))
                            .cornerRadius(200)
                    } else {
                        Text("Continue")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color(hex: "#4169E1"))
                            .cornerRadius(200)
                    }
                }
                .disabled(isCreatingCompetition)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $navigateToPlayers) {
            if let competitionId = newCompetitionId {
                WebCompetitionPlayersView(
                    competitionId: competitionId,
                    competitionName: "Competition",
                    onContinue: onContinue
                )
            }
        }
        .onAppear {
            Analytics.shared.trackScreen(name: "how_to_win")
        }
    }

    // MARK: - Actions

    private func handleContinue() {
        Analytics.shared.trackTap(
            elementId: "how_to_win_view_invite_to_play_tap",
            screenName: "how_to_win"
        )

        if isWebUser {
            createCompetitionAndNavigate()
        } else {
            onContinue()
        }
    }

    private func createCompetitionAndNavigate() {
        guard let userId = Auth.auth().currentUser?.uid else {
            creationError = "Not signed in. Please try again."
            return
        }

        isCreatingCompetition = true
        creationError = nil

        let db = Firestore.firestore()
        let competitionRef = db.collection("competitions").document()
        let competitionId = competitionRef.documentID
        let timestamp = Timestamp()

        // 1. Member first (matches MyCompsView order)
        competitionRef.collection("members").document(userId).setData([
            "userId": userId,
            "coins": 1000
        ]) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isCreatingCompetition = false
                    self.creationError = "Couldn't create competition. Please try again."
                }
                print("❌ Failed to add creator as member: \(error.localizedDescription)")
                return
            }

            // 2. Competition document (matching MyCompsView fields exactly)
            competitionRef.setData([
                "id": competitionId,
                "description": "Competition",
                "timestamp": timestamp,
                "hostId": userId
            ]) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.isCreatingCompetition = false
                        self.creationError = "Couldn't create competition. Please try again."
                    }
                    print("❌ Failed to create competition: \(error.localizedDescription)")
                    return
                }

                // 3. GroupMemberships
                db.collection("groupMemberships")
                    .document(userId)
                    .collection("competitions")
                    .document(competitionId)
                    .setData(["competitionId": competitionId]) { error in
                        DispatchQueue.main.async {
                            self.isCreatingCompetition = false

                            if let error = error {
                                print("⚠️ Failed to link groupMembership: \(error.localizedDescription)")
                            }

                            Analytics.shared.track(
                                event: "competition_created",
                                properties: [
                                    "competition_id": competitionId,
                                    "source": "how_to_win"
                                ]
                            )

                            self.newCompetitionId = competitionId
                            self.navigateToPlayers = true
                        }
                    }
            }
        }
    }
}

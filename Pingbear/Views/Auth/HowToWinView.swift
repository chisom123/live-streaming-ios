import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct HowToWinView: View {
    var onCreated: (Competition) -> Void
    @State private var isCreating = false

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image("hero")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            Color.black.opacity(0.55)
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
                        Text("Win 450")
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

                Spacer()

                Button(action: {
                    if !isCreating { createNewCompetition() }
                }) {
                    Text(isCreating ? "Creating..." : "Continue")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isCreating ? .white.opacity(0.6) : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(isCreating ? Color(hex: "#4169E1").opacity(0.5) : Color(hex: "#4169E1"))
                        .cornerRadius(200)
                }
                .disabled(isCreating)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Analytics.shared.trackScreen(name: "how_to_win")
        }
    }

    private func createNewCompetition() {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        isCreating = true

        let db = Firestore.firestore()

        db.collection("users").document(userID).getDocument { (document, error) in
            if let error = error {
                print("Failed to fetch user data: \(error.localizedDescription)")
                self.isCreating = false
                return
            }

            let competitionRef = db.collection("competitions").document()
            let newCompetitionId = competitionRef.documentID
            let timestamp = Timestamp()
            let creationDate = timestamp.dateValue()

            let creatorMemberRef = competitionRef.collection("members").document(userID)

            creatorMemberRef.setData([
                "userId": userID,
                "coins": 1000
            ]) { error in
                if let error = error {
                    print("Failed to add creator as member: \(error.localizedDescription)")
                    self.isCreating = false
                    return
                }

                let competitionData: [String: Any] = [
                    "id": newCompetitionId,
                    "description": "Competition",
                    "timestamp": timestamp,
                    "hostId": userID
                ]

                competitionRef.setData(competitionData) { error in
                    if let error = error {
                        print("Failed to create competition: \(error.localizedDescription)")
                        self.isCreating = false
                        return
                    }

                    let creatorGroupMembershipRef = db.collection("groupMemberships").document(userID)
                        .collection("competitions").document(newCompetitionId)

                    creatorGroupMembershipRef.setData(["competitionId": newCompetitionId]) { error in
                        if let error = error {
                            print("Failed to add group membership: \(error.localizedDescription)")
                        }

                        self.isCreating = false

                        let newCompetition = Competition(
                            id: newCompetitionId,
                            description: "Competition",
                            date: creationDate
                        )

                        DispatchQueue.main.async {
                            Analytics.shared.trackTap(
                                elementId: "how_to_win_continue",
                                screenName: "how_to_win"
                            )
                            Analytics.shared.trackCompetition(
                                action: "create",
                                competitionId: newCompetitionId
                            )
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            onCreated(newCompetition)
                        }
                    }
                }
            }
        }
    }
}

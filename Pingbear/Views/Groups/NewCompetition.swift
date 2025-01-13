//
//  NewCompetition.swift
//  Pingbear
//
//  Created by Ezi Agu on 02/08/1402 AP.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PostHog

struct NewCompetition: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var competitionDescription: String = ""
    @State private var errorMessage: String? = nil
    @State private var selectedCompetition: Competition?

    
    func isValidName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty
    }
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable() // Allows resizing of the image
                            .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                            .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                            .foregroundColor(Color.black) // Your desired color
                    }
                    
                    Spacer()
                    
                    Text("New Competition")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.black)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: {
                     
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable() // Allows resizing of the image
                            .aspectRatio(contentMode: .fit) // Keeps the aspect ratio intact
                            .frame(width: 27, height: 27) // Adjust the width and height to decrease the size
                            .foregroundColor(Color.black) // Your desired color
                    }
                    .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                Spacer()
                
                Text("Give your competition a name")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.bottom, 40)
                    .padding(.horizontal)
                    .onAppear {
                        PostHogSDK.shared.capture("New Competition View Opened")
                    }

                TextField("Enter competition name", text: $competitionDescription)
                    .keyboardType(.default)
                    .padding()
                    .background(Color(hex: "#F5F5F5"))
                    .foregroundColor(Color(hex: "#000"))
                    .cornerRadius(5)
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .padding(.horizontal)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(Color(hex: "#CC2255"))
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .padding(.bottom, 8)
                        .padding(.top, 20)
                        .padding(.horizontal)
                }
        
                Button(action: {
                    newgroup()
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(Color(hex: "#1199FF"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 20)
                .padding(.horizontal)
                

                Spacer()
                
            }

        }
        .fullScreenCover(item: $selectedCompetition) { competition in
            JoinSelectView(competition: competition, viewModel: MyFriendsModel(), viewModel2: AddFriendsModel())
        }
    }

    func newgroup() {

        // Get the current user's ID
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Error: User not logged in")
            return
        }
        
        // Validate the name
        guard isValidName(competitionDescription) else {
            errorMessage = "Please enter a name"
            return
        }
        
        let db = Firestore.firestore()
        let batch = db.batch()
        
        let competitionRef = db.collection("competitions").document()
        let competitionData: [String: Any] = [
            "description": competitionDescription,
            "timestamp": Timestamp()
        ]
        
        batch.setData(competitionData, forDocument: competitionRef)
        
        // Set the user as a member in the "members" subcollection of the new competition
        let memberRef = competitionRef.collection("members").document(userID)
        let memberData: [String: Any] = [
            "userId": userID
        ]
        batch.setData(memberData, forDocument: memberRef)
        
        // Correctly reference the 'groupMemberships' under the user's document
        let groupMembershipRef = db.collection("groupMemberships").document(userID)
                                      .collection("competitions").document(competitionRef.documentID)
        let membershipData: [String: Any] = [
            "competitionId": competitionRef.documentID
        ]
        batch.setData(membershipData, forDocument: groupMembershipRef)
        
        batch.commit { err in
            if let err = err {
                errorMessage = "Failed to create competition: \(err.localizedDescription)"
            } else {
                DispatchQueue.main.async {
                    selectedCompetition = Competition(
                        id: competitionRef.documentID,
                        description: competitionDescription,
                        date: Date()
                    )
                }
                PostHogSDK.shared.capture("New Competition", properties: ["name": competitionDescription])
            }
        }
    }
}

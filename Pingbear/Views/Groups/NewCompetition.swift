//
//  NewCompetition.swift
//  Pingbear
//
//  Created by Ezi Agu on 02/08/1402 AP.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import UIKit
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
                        Image("Close")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .padding(.leading, 20)
                            .padding(.top, 20)
                    }
                    
                    Spacer() // This spacer will ensure the two buttons are at opposite ends.
                }
                
                Spacer()
                
                Text("New Group")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.bottom, 40)
                    .padding(.horizontal)

                TextField("Group Name", text: $competitionDescription)
                    .keyboardType(.default)
                    .padding()
                    .background(Color(hex: "#F5F5F5"))
                    .foregroundColor(Color(hex: "#000"))
                    .cornerRadius(5)
                    .font(.system(size: 16, weight: .semibold, design: .default))
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
                    newcomp()
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

    func newcomp() {

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
        let participantRef = competitionRef.collection("participants").document(userID)
        
        let competitionData: [String: Any] = [
            "description": competitionDescription,
            "timestamp": Timestamp(),
            "userID": userID
        ]
        
        batch.setData(competitionData, forDocument: competitionRef)
        batch.setData(["userId": userID], forDocument: participantRef)
        
        batch.commit { err in
            if let err = err {
                errorMessage = "Failed to create competition: \(err.localizedDescription)"
            } else {
                DispatchQueue.main.async {
                    selectedCompetition = Competition(
                        id: competitionRef.documentID,
                        description: competitionDescription,
                        date: Date(), // Using current date as timestamp
                        userId: userID
                    )
                }
                PostHogSDK.shared.capture("New Group")
            }
        }
    }
}

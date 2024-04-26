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
    @State private var isCameraPresented = false
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
        // Firestore reference
        let db = Firestore.firestore()

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

        // Data to save, including the user ID
        let competitionData: [String: Any] = [
            "description": competitionDescription,
            "timestamp": Timestamp(), // Current time
            "userID": userID, // Adding the user ID
        ]

        // Add a new document with the competition data
        var ref: DocumentReference? = nil
        ref = db.collection("competitions").addDocument(data: competitionData) { err in
            if let err = err {
                print("Error adding document: \(err)")
            } else {
                print("Document added with user ID")

                // Get the reference to the newly created competition
                guard let newCompetitionId = ref?.documentID else {
                    print("Error fetching new competition ID")
                    return
                }

                // Add the user to the participants collection of the new competition
                let participantRef = db.collection("competitions").document(newCompetitionId).collection("participants").document(userID)
                participantRef.setData(["userId": userID]) { error in
                    if let error = error {
                        print("Error adding participant: \(error)")
                    } else {
                        print("Participant added successfully.")
                        self.fetchNewCompetitionDetails(newCompetitionId)
                        PostHogSDK.shared.capture("New Group")

                    }
                }
            }
        }
    }

    func fetchNewCompetitionDetails(_ competitionId: String) {
        let db = Firestore.firestore()

        db.collection("competitions").document(competitionId).getDocument { (document, error) in
            if let error = error {
                print("Error fetching competition details: \(error)")
                return
            }

            if let document = document, document.exists {
                let data = document.data()
                guard let description = data?["description"] as? String,
                      let timestamp = data?["timestamp"] as? Timestamp,
                      let userId = data?["userID"] as? String else { // Fetch the userID as well
                    print("Error reading competition data")
                    return
                }

                let competition = Competition(
                    id: document.documentID,
                    description: description,
                    date: timestamp.dateValue(), 
                    userId: userId
                )

                DispatchQueue.main.async {
                    self.selectedCompetition = competition
                }
            } else {
                print("Competition does not exist")
            }
        }
    }



}

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import PostHog

struct NameEntryView: View {
    let phoneNumber: String
    @State private var username: String = ""
    @State private var errorMessage: String? = nil
    @State private var navigateToHome = false
    
    func isValidUsername(_ username: String) -> Bool {
        let trimmedName = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty
    }

    var body: some View {
        VStack {
            Text("Create a username")
                .font(.system(size: 18, weight: .semibold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.bottom, 40)
                .padding(.horizontal)
            
            TextField("Enter your username", text: $username)
                .padding()
                .background(Color(hex: "#F5F5F5"))
                .foregroundColor(Color(hex: "#000"))
                .cornerRadius(5)
                .font(.system(size: 16, weight: .medium, design: .default))
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(Color(hex: "#CC2255"))
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .padding(.bottom, 10)
                    .padding(.top, 20)
                    .padding(.horizontal)
            }
            
            Button(action: {
                self.checkUsernameAndSaveToFirestore()
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

            NavigationLink(destination: ContentView(), isActive: $navigateToHome) {
                EmptyView()
            }.isDetailLink(false) // To avoid any potential navigation issues
        }
        .padding()
    }
    
    func checkUsernameAndSaveToFirestore() {
        // Process username to be lowercase with no spaces
        let processedUsername = username.lowercased().replacingOccurrences(of: " ", with: "")
        
       guard isValidUsername(processedUsername) else {
           errorMessage = "Please enter your username"
           return
       }

       let db = Firestore.firestore()
       
       // Check if username is already taken
       db.collection("users").whereField("username", isEqualTo: processedUsername).getDocuments { (querySnapshot, err) in
           if let err = err {
               self.errorMessage = "Error checking username: \(err.localizedDescription)"
           } else if querySnapshot!.documents.isEmpty {
               // Username is unique, proceed to save
               self.saveUsernameToFirestore(processedUsername: processedUsername)
           } else {
               // Username already exists
               self.errorMessage = "This username is already taken"
           }
       }
   }

    func saveUsernameToFirestore(processedUsername: String) {
       guard let userID = Auth.auth().currentUser?.uid else {
           errorMessage = "Error fetching user ID"
           return
       }
       
       let db = Firestore.firestore()
       
       db.collection("users").document(userID).setData([
           "username": processedUsername, // Save username instead of name
           "phoneNumber": phoneNumber
       ], merge: true) { error in
           if let error = error {
               self.errorMessage = "Error saving user: \(error.localizedDescription)"
           } else {
               self.navigateToHome = true
               UserDefaults.standard.set(true, forKey: "isLoggedIn")
               UserDefaults.standard.synchronize()
               PostHogSDK.shared.capture("New User - \(userID)")
               
               newcomp()
               
               // Add the user to the participants collection of the new competition
               let participantRef = db.collection("competitions").document("NME35S5xac4Qbh0QsxEc").collection("participants").document(userID)
               participantRef.setData(["userId": userID]) { error in
                   if let error = error {
                       print("Error adding participant: \(error)")
                   } else {
                       print("Participant added successfully.")
                   }
               }
               
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

            // Data to save, including the user ID
            let competitionData: [String: Any] = [
                "description": "\(processedUsername)'s group 😁",
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

                        }
                    }
                }
            }
        }
        
   }

}

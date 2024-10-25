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

    var body: some View {
        VStack {
            Text("Create a username")
                .font(.system(size: 18, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.bottom, 40)
                .padding(.horizontal)
                .onAppear {
                    PostHogSDK.shared.capture("Username Entry View Opened")
                }
            
            TextField("Enter your username", text: $username)
                .padding()
                .background(Color(hex: "#F5F5F5"))
                .foregroundColor(Color(hex: "#000"))
                .cornerRadius(5)
                .font(.system(size: 16, weight: .bold, design: .default))
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(Color(hex: "#CC2255"))
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .padding(.bottom, 10)
                    .padding(.top, 20)
                    .padding(.horizontal)
                    .onAppear {
                        PostHogSDK.shared.capture("Username Entry Error", properties: ["error": error])
                    }
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

            NavigationLink(destination: ContactInfoView(), isActive: $navigateToHome) {
                EmptyView()
            }.isDetailLink(false) // To avoid any potential navigation issues
        }
        .padding()
        .navigationBarHidden(true)
    }
    
    func checkUsernameAndSaveToFirestore() {
        // Process username to be lowercase with no spaces
        let processedUsername = username.lowercased().replacingOccurrences(of: " ", with: "")
        
        // Use the new validation function
        let validation = isValidUsername(processedUsername)
        guard validation.isValid else {
            errorMessage = validation.error
            PostHogSDK.shared.capture("Username Validation Failed", properties: ["username": processedUsername, "error": validation.error ?? "No error provided"])
            return
        }

        let db = Firestore.firestore()
       
        // Check if username is already taken
        db.collection("users").whereField("username", isEqualTo: processedUsername).getDocuments { (querySnapshot, err) in
            if let err = err {
                errorMessage = "Error checking username: \(err.localizedDescription)"
                PostHogSDK.shared.capture("Username Check Failed", properties: ["error": err.localizedDescription])
            } else if querySnapshot!.documents.isEmpty {
                // Username is unique, proceed to save
                saveUsernameToFirestore(processedUsername: processedUsername)
            } else {
                // Username already exists
                errorMessage = "This username is already taken"
                PostHogSDK.shared.capture("Username Already Taken", properties: ["username": processedUsername])
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
               PostHogSDK.shared.capture("Username Save Failed", properties: ["error": error.localizedDescription])
           } else {
               newgroup(processedUsername: processedUsername)
               self.navigateToHome = true
               UserDefaults.standard.set(true, forKey: "isLoggedIn")
               UserDefaults.standard.synchronize()
               PostHogSDK.shared.capture("New User Created", properties: ["userID": userID, "username": processedUsername])
           }
       }
   }
    
    func newgroup(processedUsername: String) {

        // Get the current user's ID
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Error: User not logged in")
            return
        }
        
        let db = Firestore.firestore()
        
        createCompetitionAndAddMember(db: db, userID: userID, processedUsername: processedUsername) { result in
            if case .failure(let error) = result {
                self.errorMessage = "Failed to create group: \(error.localizedDescription)"
                PostHogSDK.shared.capture("Group Creation Failed", properties: ["error": error.localizedDescription])
            }
        }
    }

    func createCompetitionAndAddMember(db: Firestore, userID: String, processedUsername: String, completion: @escaping (Result<String, Error>) -> Void) {
        let competitionRef = db.collection("competitions").document()
        let competitionID = competitionRef.documentID
        
        let competitionData: [String: Any] = [
            "description": "How to use Pingbear",
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        let batch = db.batch()
        
        // Set competition data
        batch.setData(competitionData, forDocument: competitionRef)
        
        // Add user as a member
        let memberRef = competitionRef.collection("members").document(userID)
        let memberData: [String: Any] = ["userId": userID]
        batch.setData(memberData, forDocument: memberRef)
        
        // Add to user's group memberships
        let groupMembershipRef = db.collection("groupMemberships").document(userID)
                                    .collection("competitions").document(competitionID)
        let membershipData: [String: Any] = ["competitionId": competitionID]
        batch.setData(membershipData, forDocument: groupMembershipRef)
        
        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(competitionID))
                PostHogSDK.shared.capture("Initial Empty User Group Created")
            }
        }
    }
}

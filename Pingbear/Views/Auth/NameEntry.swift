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

            NavigationLink(destination: ContentView(), isActive: $navigateToHome) {
                EmptyView()
            }.isDetailLink(false) // To avoid any potential navigation issues
        }
        .padding()
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
        let batch = db.batch()
        
        let competitionRef = db.collection("competitions").document()
        let competitionData: [String: Any] = [
            "description": "Welcome to Pingbear 👋",
            "timestamp": Timestamp()
        ]
        
        batch.setData(competitionData, forDocument: competitionRef)
        
        let predefinedVideos = [
            ("https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c.appspot.com/o/welcome_videos%2F9dd60ca036274b445c8dbb1b1eacfc4a.mp4?alt=media&token=7cea108e-87f4-4398-aa82-13d11e747e4e", "sChx4qnu3sgKXJpCl4NADXo5nhh1"),
            ("https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c.appspot.com/o/welcome_videos%2Ff6a10a403a15f3e8ca7d880e46030197.mp4?alt=media&token=da387ff5-1290-4485-a2d3-6c9cefa7abba", "RGTNB4JpPhQBzRoMloZz6Z2s9Nz2"),
            ("https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c.appspot.com/o/welcome_videos%2F5e26c5c5712f6507d11ebf24ba777e09.mp4?alt=media&token=26150bbf-25d2-4be0-8a28-fa29a20c02a0", "1tZCGhXDSnf0z8Scpb8KN9TV2YI3"),
            ("https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c.appspot.com/o/welcome_videos%2F4d77cc666c787df149af7a2051db9fcb.mp4?alt=media&token=125bc365-0e29-4cc6-a3ac-b756f354b968", "sK5iDY6jsya6fBcDQW4EBgromZ72")
        ]

        // Add predefined video entries with dynamic user data
        for (videoURL, userID) in predefinedVideos {
            let entryRef = competitionRef.collection("entries").document()
            let entryData: [String: Any] = [
                "userId": userID,  // Assigning current user's ID to each entry
                "videoUrl": videoURL,
                "timestamp": FieldValue.serverTimestamp(),
                "superstar": false  // Assuming default superstar status is false
            ]
            batch.setData(entryData, forDocument: entryRef)
        }
        
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
                errorMessage = "Failed to create group: \(err.localizedDescription)"
                PostHogSDK.shared.capture("Group Creation Failed", properties: ["error": err.localizedDescription])
            } else {
                PostHogSDK.shared.capture("Initial User Group Created", properties: ["userID": userID, "groupID": competitionRef.documentID])
            }
        }
    }
}

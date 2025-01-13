import FirebaseAuth
import FirebaseFirestore

class AdminAuthManager: ObservableObject {
    @Published var isAdmin = false
    private let adminUserId = "umA6LLuvyHWfc6cnYb2PYjBp7oj1" // Replace with your user ID
    private let adminPhoneNumber = "+447578559500" // Replace with your phone number
    
    static let shared = AdminAuthManager()
    private init() {}
    
    func checkAdminStatus() {
        guard let currentUser = Auth.auth().currentUser else {
            isAdmin = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(currentUser.uid).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data(),
                  let phoneNumber = data["phoneNumber"] as? String else {
                self?.isAdmin = false
                return
            }
            
            self.isAdmin = currentUser.uid == self.adminUserId && phoneNumber == self.adminPhoneNumber
        }
    }
}

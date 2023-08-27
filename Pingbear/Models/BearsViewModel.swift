import SwiftUI
import Combine
import Firebase
import FirebaseFirestore
import FirebaseAuth

class BearsViewModel: ObservableObject {
    @Published var pBills: Int = 0
    @Published var bears: [Bear] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        fetchPBills()
        fetchData()
    }
    
    private var db = Firestore.firestore()

    private func fetchPBills() {
        // Assuming you've a way to fetch the current user's ID
        let userID = Auth.auth().currentUser?.uid ?? ""

        Firestore.firestore().collection("users").document(userID).getDocument { snapshot, error in
            guard let data = snapshot?.data() else { return }
            self.pBills = data["pBills"] as? Int ?? 0
        }
    }

    func fetchData() {
           db.collection("bears").getDocuments { (querySnapshot, error) in
               guard let documents = querySnapshot?.documents else {
                   print("No documents")
                   return
               }

               self.bears = documents.map { queryDocumentSnapshot -> Bear in
                   let data = queryDocumentSnapshot.data()
                   let name = data["name"] as? String ?? ""
                   let price = data["price"] as? Int ?? 0
                   let imageUrl = data["imageUrl"] as? String ?? ""
                   return Bear(id: queryDocumentSnapshot.documentID, name: name, price: price, imageUrl: imageUrl)
               }
           }
       }
}


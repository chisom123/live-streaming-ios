import SwiftUI
import Combine
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine
import Flurry_iOS_SDK

class BearsViewModel: ObservableObject {
    @Published var pBills: Int = 0
    @Published var bears: [Bear] = []
    @Published var ownedBears: [Bear] = []
    @Published var currentUserIcon: String = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        fetchPBills()
        fetchData()
        fetchOwnedBears()
    }
    
    private var db = Firestore.firestore()

    private func fetchPBills() {
        // Assuming you've a way to fetch the current user's ID
        let userID = Auth.auth().currentUser?.uid ?? ""

        Firestore.firestore().collection("users").document(userID).getDocument { snapshot, error in
            DispatchQueue.main.async {
                guard let data = snapshot?.data() else { return }
                self.pBills = data["pBills"] as? Int ?? 0
                self.currentUserIcon = data["icon"] as? String ?? ""
            }
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

    func purchaseBear(_ bear: Bear) {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        // Deduct P-Bills
        let newPBills = pBills - bear.price
        db.collection("users").document(userID).updateData(["pBills": newPBills]) { error in
            if let error = error {
                print("Error deducting P-Bills: \(error.localizedDescription)")
            } else {
                // Add the bear to the user's bears sub-collection
                let bearData: [String: Any] = ["name": bear.name, "imageUrl": bear.imageUrl, "price": bear.price]
                self.db.collection("users").document(userID).collection("bears").addDocument(data: bearData) { error in
                    if let error = error {
                        print("Error adding bear to user's collection: \(error.localizedDescription)")
                    } else {
                        // Update local P-Bills value
                        self.pBills = newPBills
                        self.updateUserIcon(with: bear.imageUrl)
                        // Optionally, fetch the user's bears again or just append the new bear to a local list
                        self.ownedBears.append(bear)
                        Flurry.log(eventName: "Bears-Purchased")
                    }
                }
            }
        }
    }

    func fetchOwnedBears() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(userID).collection("bears").getDocuments { (querySnapshot, error) in
            guard let documents = querySnapshot?.documents else {
                print("No owned bears found")
                return
            }

            self.ownedBears = documents.map { queryDocumentSnapshot -> Bear in
                let data = queryDocumentSnapshot.data()
                let name = data["name"] as? String ?? ""
                let price = data["price"] as? Int ?? 0
                let imageUrl = data["imageUrl"] as? String ?? ""
                return Bear(id: queryDocumentSnapshot.documentID, name: name, price: price, imageUrl: imageUrl)
            }
        }
    }

    func updateUserIcon(with imageUrl: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let data: [String: Any] = ["icon": imageUrl]
        db.collection("users").document(userID).setData(data, merge: true) { error in
            if let error = error {
                print("Error updating user's icon: \(error.localizedDescription)")
            } else {
                // Update the currentUserIcon here after successful database update
                self.currentUserIcon = imageUrl
                print("User's icon successfully updated!")
            }
        }
    }

    func listenForPBillsPurchase(pbillViewModel: PbillViewModel) {
        pbillViewModel.$purchaseCompleted
            .filter { $0 == true } // Only proceed if purchaseCompleted is true
            .sink { [weak self] _ in
                self?.fetchPBills()
                pbillViewModel.purchaseCompleted = false // Reset purchaseCompleted in pbillViewModel
            }
            .store(in: &cancellables)
    }


}


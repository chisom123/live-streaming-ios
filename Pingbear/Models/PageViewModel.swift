import SwiftUI
import Firebase

class PageViewModel: ObservableObject {
    @Published var showDemo = false

    private var db = Firestore.firestore()

    init() {
        fetchPageSetting()
    }
    
    private func fetchPageSetting() {
        db.collection("landing").document("l9nthZ3iSjJa890CWHVl").getDocument { (document, error) in
            if let document = document, document.exists {
                if let pageValue = document.get("page") as? Bool {
                    DispatchQueue.main.async {
                        self.showDemo = pageValue
                    }
                }
            } else {
                print("Document does not exist or error fetching document: \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }
}

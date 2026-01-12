import Foundation
import FirebaseAuth
import FirebaseFirestore

class PotHistoryViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var pastPots: [PastPotParticipation] = []
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    struct PastPotParticipation: Identifiable {
        let id: String // participant doc ID
        let potId: String
        let totalStars: Int
        let finalRank: Int?
        let prizeAmount: Double?
        let joinedAt: Date
        let calculatedAt: Date?
        let potEndDate: Date?
        let potStatus: String?
    }
    
    func loadPotHistory() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Query all participant documents for this user across all pots
        db.collectionGroup("participants")
            .whereField("user_id", isEqualTo: userId)
            .order(by: "joined_at", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to load: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                // Parse participant documents
                var pots: [PastPotParticipation] = []
                let group = DispatchGroup()
                
                for doc in documents {
                    let data = doc.data()
                    
                    // Extract pot ID from document path
                    // Path format: global_pots/{potId}/participants/{userId}
                    guard let potId = doc.reference.parent.parent?.documentID else {
                        continue
                    }
                    
                    let totalStars = data["total_stars"] as? Int ?? 0
                    let finalRank = data["final_rank"] as? Int
                    let prizeAmount = data["prize_amount"] as? Double
                    let joinedAt = (data["joined_at"] as? Timestamp)?.dateValue() ?? Date()
                    let calculatedAt = (data["calculated_at"] as? Timestamp)?.dateValue()
                    
                    // Fetch pot details
                    group.enter()
                    doc.reference.parent.parent?.getDocument { potDoc, _ in
                        let potData = potDoc?.data()
                        let potEndDate = (potData?["end_date"] as? Timestamp)?.dateValue()
                        let potStatus = potData?["status"] as? String
                        
                        let participation = PastPotParticipation(
                            id: potId,
                            potId: potId,
                            totalStars: totalStars,
                            finalRank: finalRank,
                            prizeAmount: prizeAmount,
                            joinedAt: joinedAt,
                            calculatedAt: calculatedAt,
                            potEndDate: potEndDate,
                            potStatus: potStatus
                        )
                        
                        pots.append(participation)
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    // Remove duplicates based on potId
                    var seen = Set<String>()
                    let uniquePots = pots.filter { pot in
                        if seen.contains(pot.potId) {
                            return false
                        }
                        seen.insert(pot.potId)
                        return true
                    }
                    
                    // Sort by joined date (newest first)
                    self.pastPots = uniquePots.sorted { $0.joinedAt > $1.joinedAt }
                    self.isLoading = false
                }
            }
    }
    
    func refresh() async {
        await MainActor.run {
            loadPotHistory()
        }
    }
}

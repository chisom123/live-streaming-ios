import Foundation
import FirebaseFirestore

struct RatingLink: Identifiable {
    let id: String
    let recruiterId: String
    let assignedUserId: String?
    let linkId: String
    var title: String
    let description: String
    let url: String
    let createdAt: Date
    var totalRatings: Int
    var photoUrl: String?
    
    // Calculated properties for ratings
    var averageRating: Double = 0.0
    var ratingCount: Int = 0
    
    var hasRatings: Bool {
        ratingCount > 0
    }
    
    init(documentID: String, data: [String: Any]) {
        self.id = documentID
        self.recruiterId = data["recruiterId"] as? String ?? ""
        self.assignedUserId = data["assignedUserId"] as? String
        self.linkId = data["linkId"] as? String ?? ""
        self.title = data["title"] as? String ?? "Untitled Link"
        self.description = data["description"] as? String ?? ""
        self.url = data["url"] as? String ?? ""
        
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        
        self.totalRatings = data["totalRatings"] as? Int ?? 0
        self.photoUrl = data["photoUrl"] as? String
    }
}

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Theme Model
struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    let competitionId: String
    let createdBy: String
    let createdAt: Date
    
    // For creating new themes
    static func createNew(name: String, competitionId: String, createdBy: String) -> Theme {
        return Theme(
            id: UUID().uuidString,
            name: name,
            competitionId: competitionId,
            createdBy: createdBy,
            createdAt: Date()
        )
    }
}

// MARK: - Themes Service
class ThemesService {
    private let db = Firestore.firestore()
    
    // Fetch themes for a competition
    func fetchThemes(for competitionId: String, completion: @escaping ([Theme]) -> Void) {
        
        // Then fetch competition-specific themes
        db.collection("competitions")
            .document(competitionId)
            .collection("themes")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching themes: \(error)")
                    return
                }
                
                let customThemes = snapshot?.documents.compactMap { document -> Theme? in
                    let data = document.data()
                    
                    guard let name = data["name"] as? String,
                          let createdBy = data["createdBy"] as? String,
                          let timestamp = data["createdAt"] as? Timestamp else {
                        return nil
                    }
                    
                    return Theme(
                        id: document.documentID,
                        name: name,
                        competitionId: competitionId,
                        createdBy: createdBy,
                        createdAt: timestamp.dateValue()
                    )
                } ?? []
                
                // Combine default and custom themes, with custom at the top
                let allThemes = customThemes
                completion(allThemes)
            }
    }
    
    // Add a new theme to a competition
    func addTheme(theme: Theme, completion: @escaping (Bool) -> Void) {
        
        let themeData: [String: Any] = [
            "name": theme.name,
            "competitionId": theme.competitionId,
            "createdBy": theme.createdBy,
            "createdAt": Timestamp(date: theme.createdAt)
        ]
        
        db.collection("competitions")
            .document(theme.competitionId)
            .collection("themes")
            .document(theme.id)
            .setData(themeData) { error in
                if let error = error {
                    print("Error adding theme: \(error)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
    }
}

// MARK: - Themes ViewModel
class ThemesViewModel: ObservableObject {
    @Published var themes: [Theme] = []
    @Published var isLoading: Bool = false
    private let service = ThemesService()
    
    func loadThemes(for competitionId: String) {
        isLoading = true
        
        service.fetchThemes(for: competitionId) { [weak self] themes in
            DispatchQueue.main.async {
                self?.themes = themes
                self?.isLoading = false
            }
        }
    }
    
    func addTheme(name: String, competitionId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let newTheme = Theme.createNew(
            name: name,
            competitionId: competitionId,
            createdBy: userId
        )
        
        service.addTheme(theme: newTheme) { [weak self] success in
            if success {
                DispatchQueue.main.async {
                    self?.themes.insert(newTheme, at: 0)
                }
            }
            completion(success)
        }
    }
}

import Foundation
import FirebaseFirestore
import FirebaseAuth

class GlobalLeaderboardManager: ObservableObject {
    static let shared = GlobalLeaderboardManager()
    
    // MARK: - Published Properties
    @Published var isLoading: Bool = false
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var configListener: ListenerRegistration?
    
    // Cached config values
    private var cachedConfig: GlobalLeaderboardConfig?
    
    // MARK: - Config Structure
    struct GlobalLeaderboardConfig {
        let potMaxParticipants: Int
        let firstPlacePrize: Double
        let decayRate: Double
        let minPayout: Double
        
        static var `default`: GlobalLeaderboardConfig {
            return GlobalLeaderboardConfig(
                potMaxParticipants: 1000,
                firstPlacePrize: 100.0,
                decayRate: 0.0,
                minPayout: 0.01
            )
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupRealtimeListener()
    }
    
    deinit {
        configListener?.remove()
    }
    
    // MARK: - Real-time Configuration Listener
    private func setupRealtimeListener() {
        configListener?.remove()
        
        configListener = db.collection("app_config").document("global_leaderboard")
            .addSnapshotListener { [weak self] documentSnapshot, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("GlobalLeaderboard: Error listening to config: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let document = documentSnapshot, document.exists else {
                        print("GlobalLeaderboard: Config document does not exist, using defaults")
                        self.cachedConfig = .default
                        return
                    }
                    
                    self.updateConfigFromDocument(document)
                }
            }
    }
    
    private func updateConfigFromDocument(_ document: DocumentSnapshot) {
        let data = document.data() ?? [:]
        
        let config = GlobalLeaderboardConfig(
            potMaxParticipants: data["pot_max_participants"] as? Int ?? 1000,
            firstPlacePrize: data["first_place_prize"] as? Double ?? 100.0,
            decayRate: data["decay_rate"] as? Double ?? 0.0,
            minPayout: data["min_payout"] as? Double ?? 0.01
        )
        
        self.cachedConfig = config
        
        print("✅ GlobalLeaderboard: Config updated - Pot Size: \(config.potMaxParticipants), Prize: $\(config.firstPlacePrize)")
    }
    
    func getConfig() -> GlobalLeaderboardConfig {
        return cachedConfig ?? .default
    }
}

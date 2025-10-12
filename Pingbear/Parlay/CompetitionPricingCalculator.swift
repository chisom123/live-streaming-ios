import Foundation
import FirebaseFirestore

class CompetitionPricingCalculator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading: Bool = false
    @Published var isOffline: Bool = false
    
    // MARK: - Private Properties
    private var cachedHouseEdge: Double = 0.20 // Default fallback
    private var cachedAccuracyRate: Double = 0.60 // Default fallback
    private var cachedBonusPoolPercentage: Double = 0.50 // Default 50% of lost stake goes to bonus pool
    private var lastFetchTime: Date?
    private let cacheExpirationInterval: TimeInterval = 60 // 1 minute
    private let db = Firestore.firestore()
    
    // Real-time listener and error handling
    private var configListener: ListenerRegistration?
    private var retryCount = 0
    private let maxRetries = 3
    private var lastUpdateTime: Date?
    private let debounceInterval: TimeInterval = 0.5
    
    // MARK: - Initialization
    init() {
        setupRealtimeListener()
    }
    
    deinit {
        configListener?.remove()
    }
    
    // MARK: - Real-time Configuration
    private func setupRealtimeListener() {
        configListener?.remove() // Remove existing listener before creating new one
        
        configListener = db.collection("app_config").document("pricing")
            .addSnapshotListener { [weak self] documentSnapshot, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error listening to pricing config: \(error.localizedDescription)")
                        self.handleListenerError()
                        return
                    }
                    
                    // Reset error state on successful connection
                    self.isOffline = false
                    self.retryCount = 0
                    
                    guard let document = documentSnapshot, document.exists else {
                        print("Pricing config document does not exist, using defaults")
                        return
                    }
                    
                    self.updateConfigFromDocument(document)
                }
            }
    }
    
    private func handleListenerError() {
        isOffline = true
        
        guard retryCount < maxRetries else {
            print("Max retries reached for pricing config listener")
            return
        }
        
        retryCount += 1
        let delay = Double(retryCount * 2) // Exponential backoff: 2s, 4s, 6s
        
        print("Retrying pricing config listener in \(delay) seconds (attempt \(retryCount)/\(maxRetries))")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.setupRealtimeListener()
        }
    }
    
    private func updateConfigFromDocument(_ document: DocumentSnapshot) {
        // Debounce rapid updates
        let now = Date()
        if let lastUpdate = lastUpdateTime,
           now.timeIntervalSince(lastUpdate) < debounceInterval {
            return
        }
        lastUpdateTime = now
        
        let data = document.data() ?? [:]
        var hasChanges = false
        
        // Update cached values if available with validation logging
        if let houseEdge = data["house_edge"] as? Double {
            let clampedValue = max(0.0, min(1.0, houseEdge))
            if houseEdge != clampedValue {
                print("⚠️ House edge value \(houseEdge) was clamped to \(clampedValue)")
            }
            if self.cachedHouseEdge != clampedValue {
                self.cachedHouseEdge = clampedValue
                hasChanges = true
            }
        }
        
        if let accuracyRate = data["accuracy_rate"] as? Double {
            let clampedValue = max(0.0, min(1.0, accuracyRate))
            if accuracyRate != clampedValue {
                print("⚠️ Accuracy rate value \(accuracyRate) was clamped to \(clampedValue)")
            }
            if self.cachedAccuracyRate != clampedValue {
                self.cachedAccuracyRate = clampedValue
                hasChanges = true
            }
        }
        
        if let bonusPoolPercentage = data["bonus_pool_percentage"] as? Double {
            let clampedValue = max(0.0, min(1.0, bonusPoolPercentage))
            if bonusPoolPercentage != clampedValue {
                print("⚠️ Bonus pool percentage value \(bonusPoolPercentage) was clamped to \(clampedValue)")
            }
            if self.cachedBonusPoolPercentage != clampedValue {
                self.cachedBonusPoolPercentage = clampedValue
                hasChanges = true
            }
        }
        
        if hasChanges {
            print("✅ Updated pricing config - House Edge: \(self.cachedHouseEdge), Accuracy Rate: \(self.cachedAccuracyRate), Bonus Pool: \(self.cachedBonusPoolPercentage)")
            
            // Trigger UI updates only if values actually changed
            self.objectWillChange.send()
        }
        
        lastFetchTime = Date()
    }
    
    // MARK: - Private Methods
    private func getHouseEdge() -> Double {
        return cachedHouseEdge
    }
    
    private func getAssumedAccuracyRate() -> Double {
        return cachedAccuracyRate
    }
    
    private func getBonusPoolPercentage() -> Double {
        return cachedBonusPoolPercentage
    }
    
    // MARK: - Public Methods
    
    func getParlayMultiplier(numberOfPredictions: Int) -> Double {
        guard numberOfPredictions > 0 else { return 1.0 }
        
        let accuracyRate = getAssumedAccuracyRate()
        let winProbability = pow(accuracyRate, Double(numberOfPredictions))
        let fairMultiplier = 1.0 / winProbability
        
        let houseEdge = getHouseEdge()
        let calculatedMultiplier = fairMultiplier * (1.0 - houseEdge)
        
        return min(calculatedMultiplier, 100.0)
    }

    func calculateParlayPayout(entryCost: Int, predictions: [String: Int]) -> Int {
        guard !predictions.isEmpty else { return 0 }
        
        let multiplier = getParlayMultiplier(numberOfPredictions: predictions.count)
        let finalPayout = Double(entryCost) * multiplier
        
        return Int(round(finalPayout))
    }
    
    // MARK: - Bonus Pool Calculation
    
    /// Calculate the total bonus pool from a lost stake
    func calculateBonusPool(lostStake: Int) -> Int {
        let bonusPoolPercentage = getBonusPoolPercentage()
        let bonusPool = Double(lostStake) * bonusPoolPercentage
        return Int(floor(bonusPool)) // Always round down
    }
    
    /// Calculate individual rater's share of the bonus pool
    func calculateRaterBonus(bonusPool: Int, totalPredictions: Int) -> Int {
        guard totalPredictions > 0 else { return 0 }
        let share = Double(bonusPool) / Double(totalPredictions)
        return Int(floor(share)) // Always round down
    }
    
    // MARK: - Manual Refresh (optional)
    func refreshConfig() async -> Bool {
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let document = try await db.collection("app_config").document("pricing").getDocument()
            
            await MainActor.run {
                self.isLoading = false
                self.isOffline = false
                if document.exists {
                    self.updateConfigFromDocument(document)
                }
            }
            
            return true
        } catch {
            print("Error fetching pricing config: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.isOffline = true
            }
            return false
        }
    }
    
    // MARK: - Utility Methods
    
    /// Get current configuration for debugging/admin purposes
    func getCurrentConfig() -> (houseEdge: Double, accuracyRate: Double, bonusPoolPercentage: Double, isOnline: Bool, lastUpdate: Date?) {
        return (cachedHouseEdge, cachedAccuracyRate, cachedBonusPoolPercentage, !isOffline, lastFetchTime)
    }
    
    /// Force reconnection (useful for handling app foreground events)
    func reconnect() {
        retryCount = 0
        setupRealtimeListener()
    }
}

// MARK: - Shared Instance
extension CompetitionPricingCalculator {
    static let shared = CompetitionPricingCalculator()
}

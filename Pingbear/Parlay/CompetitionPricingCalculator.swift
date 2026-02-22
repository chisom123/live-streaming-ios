import Foundation
import FirebaseFirestore

class CompetitionPricingCalculator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading: Bool = false
    @Published var isOffline: Bool = false
    
    // MARK: - Private Properties
    private var cachedHouseEdge: Double = 0.10 // Default fallback
    private var cachedRakebackPercentage: Double = 0.0 // Default: no rakeback
    private var lastFetchTime: Date?
    private let cacheExpirationInterval: TimeInterval = 60 // 1 minute
    private var cachedStarAccuracyRates: [Int: Double] = [
        1: 0.30,  // 1-star: 30% accurate (lowest accuracy)
        2: 0.40,  // 2-star: 40% accurate
        3: 0.50,  // 3-star: 50% accurate
        4: 0.60,  // 4-star: 60% accurate
        5: 0.70   // 5-star: 70% accurate (highest accuracy)
    ]
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
        configListener?.remove()
        
        configListener = db.collection("app_config").document("pricing")
            .addSnapshotListener { [weak self] documentSnapshot, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error listening to pricing config: \(error.localizedDescription)")
                        self.handleListenerError()
                        return
                    }
                    
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
        let now = Date()
        if let lastUpdate = lastUpdateTime,
           now.timeIntervalSince(lastUpdate) < debounceInterval {
            return
        }
        lastUpdateTime = now
        
        let data = document.data() ?? [:]
        var hasChanges = false
        
        if let starRates = data["star_accuracy_rates"] as? [String: Double] {
            for (starStr, rate) in starRates {
                if let star = Int(starStr), (1...5).contains(star) {
                    let clampedValue = max(0.01, min(0.99, rate))
                    if self.cachedStarAccuracyRates[star] != clampedValue {
                        self.cachedStarAccuracyRates[star] = clampedValue
                        hasChanges = true
                        print("⭐️ Updated star \(star) accuracy: \(clampedValue)")
                    }
                }
            }
        }
        
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
        
        if let rakebackPercentage = data["rakeback_percentage"] as? Double {
            let clampedValue = max(0.0, min(1.0, rakebackPercentage))
            if rakebackPercentage != clampedValue {
                print("⚠️ Rakeback percentage value \(rakebackPercentage) was clamped to \(clampedValue)")
            }
            if self.cachedRakebackPercentage != clampedValue {
                self.cachedRakebackPercentage = clampedValue
                hasChanges = true
            }
        }
        
        if hasChanges {
            print("✅ Updated pricing config - House Edge: \(self.cachedHouseEdge), Rakeback: \(self.cachedRakebackPercentage * 100)%")
            self.objectWillChange.send()
        }
        
        lastFetchTime = Date()
    }
    
    // MARK: - Private Methods
    private func getHouseEdge() -> Double {
        return cachedHouseEdge
    }
    
    private func getRakebackPercentage() -> Double {
        return cachedRakebackPercentage
    }
    
    // MARK: - Multiplier Calculations
    
    /// Actual multiplier for a single star rating — house edge applied and floored.
    func getSingleStarMultiplier(starRating: Int) -> Double {
        let starAccuracy = getAccuracyRate(for: starRating)
        let fairMultiplier = 1.0 / starAccuracy
        let multiplier = fairMultiplier * (1.0 - getHouseEdge())
        let rounded = floor(multiplier * 10) / 10.0
        return max(rounded, 1.1)
    }
    
    // MARK: - Public Methods
    
    func getParlayMultiplier(predictions: [String: Int]) -> Double {
        guard !predictions.isEmpty else { return 1.0 }
        
        var finalMultiplier = 1.0
        for (_, starRating) in predictions {
            finalMultiplier *= getSingleStarMultiplier(starRating: starRating)
        }
        
        return min(floor(finalMultiplier * 10) / 10.0, 100.0)
    }

    func calculateParlayPayout(entryCost: Int, predictions: [String: Int]) -> Int {
        guard !predictions.isEmpty else { return 0 }
        let multiplier = getParlayMultiplier(predictions: predictions)
        return Int(floor(Double(entryCost) * multiplier))
    }
    
    // MARK: - Rakeback Calculation
    
    /// Calculate rakeback as a percentage of gross house expected keep.
    ///
    /// Rakeback scales proportionally with actual house profitability — on parlays
    /// where the player is unlikely to win, the house expects to keep more and
    /// rakeback grows accordingly. On easy bets where the house expects less,
    /// rakeback is smaller. This guarantees House EV is always positive regardless
    /// of parlay size, star ratings, or rakeback percentage (as long as it stays below 100%).
    ///
    /// This method is called once in placeParlayBet and the result is passed through
    /// to uploadEntryAfterBet to ensure both use the exact same value.
    ///
    /// - Parameters:
    ///   - entryCost: The amount of coins staked
    ///   - predictions: The star rating predictions per friend
    /// - Returns: Rakeback amount in coins (floored, minimum 0)
    func calculateRakeback(entryCost: Int, predictions: [String: Int]) -> Int {
        let rakebackPercentage = getRakebackPercentage()
        guard rakebackPercentage > 0, !predictions.isEmpty else { return 0 }
        
        // Combined win probability across all legs
        let combinedWinProbability = predictions.values.reduce(1.0) { total, starRating in
            total * getAccuracyRate(for: starRating)
        }
        
        // Actual multiplier shown to the player
        let actualMultiplier = getParlayMultiplier(predictions: predictions)
        
        // Gross house expected keep — what house statistically expects to profit before rakeback
        let grossHouseExpectedKeep = Double(entryCost) - (combinedWinProbability * actualMultiplier * Double(entryCost))
        
        // Rakeback is a percentage of gross expected keep — always proportional, always positive
        let rakebackAmount = max(0, grossHouseExpectedKeep) * rakebackPercentage
        let flooredRakeback = Int(floor(rakebackAmount))
        
        return flooredRakeback >= 1 ? flooredRakeback : 0
    }
    
    // MARK: - Star Rating Methods
    
    func getAccuracyRate(for starRating: Int) -> Double {
        return cachedStarAccuracyRates[starRating] ?? 0.5
    }
    
    // MARK: - Manual Refresh
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
    
    func getCurrentConfig() -> (houseEdge: Double, starAccuracyRates: [Int: Double], rakebackPercentage: Double, isOnline: Bool, lastUpdate: Date?) {
        return (cachedHouseEdge, cachedStarAccuracyRates, cachedRakebackPercentage, !isOffline, lastFetchTime)
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

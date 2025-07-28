import Foundation

class CompetitionPricingCalculator {
    
    private func getHouseEdge() -> Double {
        return 0.30 // 30% house edge
    }
    
    private func getAssumedAccuracyRate() -> Double {
        return 0.50 // Assume 50% prediction accuracy per friend
    }
    
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
}

// MARK: - Shared Instance
extension CompetitionPricingCalculator {
    static let shared = CompetitionPricingCalculator()
}

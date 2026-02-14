import Foundation

/// Utility functions for slot machine mechanics in rating system
struct SlotMachineUtils {
    
    // MARK: - Multiplier Generation
    
    /// Returns a weighted random multiplier based on specified probabilities
    /// - Returns: 1x (60%), 2x (25%), 3x (10%), 5x (4%), or 10x (1%)
    static func getWeightedMultiplier() -> Int {
        let random = Double.random(in: 0..<100)
        
        if random < 60 {
            return 1    // 60% chance
        } else if random < 85 {
            return 2    // 25% chance (60 + 25 = 85)
        } else if random < 95 {
            return 3    // 10% chance (85 + 10 = 95)
        } else if random < 99 {
            return 5    // 4% chance (95 + 4 = 99)
        } else {
            return 10   // 1% chance (99 + 1 = 100)
        }
    }
    
    // MARK: - Point Calculation
    
    /// Calculates base points for a star rating (before multiplier)
    /// - Parameter stars: Rating from 1-5
    /// - Returns: Base points (100, 200, 300, 400, or 500)
    static func getBasePoints(for stars: Int) -> Int {
        guard stars >= 1 && stars <= 5 else { return 0 }
        return stars * 100
    }
    
    /// Calculates final points for a single spin
    /// - Parameters:
    ///   - stars: Rating from 1-5
    ///   - multiplier: Multiplier value (1x, 2x, 3x, 5x, or 10x)
    /// - Returns: Final points (base × multiplier)
    static func calculatePoints(stars: Int, multiplier: Int) -> Int {
        let basePoints = getBasePoints(for: stars)
        return basePoints * multiplier
    }
    
    // MARK: - Spin Result Generation
    
    /// Represents a single spin result
    struct SpinResult {
        let stars: Int
        let multiplier: Int
        let points: Int
    }
    
    /// Generates a complete spin result with random star rating and weighted multiplier
    /// - Returns: SpinResult containing stars, multiplier, and calculated points
    static func generateSpinResult() -> SpinResult {
        let stars = Int.random(in: 1...5)
        let multiplier = getWeightedMultiplier()
        let points = calculatePoints(stars: stars, multiplier: multiplier)
        
        return SpinResult(
            stars: stars,
            multiplier: multiplier,
            points: points
        )
    }
    
    /// Generates three spin results with unique star ratings (no duplicates)
    /// - Returns: Array of 3 SpinResults with different star values
    static func generateThreeSpins() -> [SpinResult] {
        // Generate 3 unique random numbers from 1-5
        var availableStars = Array(1...5)
        var spins: [SpinResult] = []
        
        for _ in 0..<3 {
            // Pick random index from remaining stars
            let randomIndex = Int.random(in: 0..<availableStars.count)
            let stars = availableStars.remove(at: randomIndex)
            
            // Generate multiplier and calculate points
            let multiplier = getWeightedMultiplier()
            let points = calculatePoints(stars: stars, multiplier: multiplier)
            
            spins.append(SpinResult(
                stars: stars,
                multiplier: multiplier,
                points: points
            ))
        }
        
        return spins
    }
    
    /// Calculates total points from multiple spin results
    /// - Parameter spins: Array of SpinResults
    /// - Returns: Sum of all points from the spins
    static func calculateTotalPoints(from spins: [SpinResult]) -> Int {
        return spins.reduce(0) { $0 + $1.points }
    }
}

// MARK: - Testing Helper

#if DEBUG
extension SlotMachineUtils {
    
    /// Test the distribution of multipliers over many iterations
    /// Prints the frequency of each multiplier to verify probabilities
    static func testMultiplierDistribution(iterations: Int = 10000) {
        var distribution: [Int: Int] = [1: 0, 2: 0, 3: 0, 5: 0, 10: 0]
        
        for _ in 0..<iterations {
            let multiplier = getWeightedMultiplier()
            distribution[multiplier, default: 0] += 1
        }
        
        print("=== Multiplier Distribution Test (\(iterations) iterations) ===")
        print("1x:  \(distribution[1]!) (\(String(format: "%.1f", Double(distribution[1]!) / Double(iterations) * 100))%) - Expected: 60%")
        print("2x:  \(distribution[2]!) (\(String(format: "%.1f", Double(distribution[2]!) / Double(iterations) * 100))%) - Expected: 25%")
        print("3x:  \(distribution[3]!) (\(String(format: "%.1f", Double(distribution[3]!) / Double(iterations) * 100))%) - Expected: 10%")
        print("5x:  \(distribution[5]!) (\(String(format: "%.1f", Double(distribution[5]!) / Double(iterations) * 100))%) - Expected: 4%")
        print("10x: \(distribution[10]!) (\(String(format: "%.1f", Double(distribution[10]!) / Double(iterations) * 100))%) - Expected: 1%")
    }
    
    /// Example usage and testing
    static func runExamples() {
        print("\n=== Example Spin Results ===")
        
        // Generate 3 spins
        let spins = generateThreeSpins()
        
        for (index, spin) in spins.enumerated() {
            print("Spin \(index + 1): \(spin.stars)★ × \(spin.multiplier)x = \(spin.points) points")
        }
        
        let totalPoints = calculateTotalPoints(from: spins)
        print("\nTotal Points: \(totalPoints)")
        print("User would pick one of: [\(spins.map { "\($0.stars)★" }.joined(separator: ", "))]")
        
        // Test distribution
        print("\n")
        testMultiplierDistribution(iterations: 100000)
    }
}
#endif

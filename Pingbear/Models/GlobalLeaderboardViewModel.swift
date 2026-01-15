import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class GlobalLeaderboardViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var isInPot = false
    @Published var errorMessage: String?
    
    @Published var potInfo: PotInfo?
    @Published var participants: [LeaderboardParticipant] = []
    @Published var userStars = 0
    @Published var userPosition = 0  // Display position (1, 2, 3...)
    @Published var userRank = 0  // Actual rank for prize calculation (1, 1, 3...)
    @Published var userPrize = 0.0
    @Published var timeRemaining = ""
    @Published var potEnded = false
    @Published var totalPrizePool = 0.0
    @Published var firstPlacePrize: Double = 0.0
    
    private let db = Firestore.firestore()
    private var timer: Timer?
    
    var userRankText: String {
        if userPosition == 0 {
            return "--"
        }
        return "#\(userPosition)"
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func loadLeaderboard() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        loadConfig()
        
        // Check if user has an active pot
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            guard let potId = document?.data()?["active_pot_id"] as? String else {
                DispatchQueue.main.async {
                    self.isInPot = false
                    self.isLoading = false
                }
                return
            }
            
            self.isInPot = true
            self.loadPotData(potId: potId, userId: userId)
        }
    }
    
    private func loadConfig() {
        db.collection("app_config").document("global_leaderboard")
            .getDocument { [weak self] document, error in
                guard let self = self else { return }
                
                if let data = document?.data() {
                    DispatchQueue.main.async {
                        self.firstPlacePrize = data["first_place_prize"] as? Double ?? 100.0
                    }
                }
            }
    }
    
    private func loadPotData(potId: String, userId: String) {
        let potRef = db.collection("global_pots").document(potId)
        
        potRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load pot: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            guard let data = document?.data(),
                  let endDateTimestamp = data["end_date"] as? Timestamp else {
                DispatchQueue.main.async {
                    self.errorMessage = "Invalid pot data"
                    self.isLoading = false
                }
                return
            }
            
            let potInfo = PotInfo(
                potId: potId,
                endDate: endDateTimestamp.dateValue(),
                firstPlacePrize: data["first_place_prize"] as? Double ?? 100.0,
                maxParticipants: data["max_participants"] as? Int ?? 1000,
                decayRate: data["decay_rate"] as? Double ?? 0.0,
                minPayout: data["min_payout"] as? Double ?? 0.01
            )
            
            DispatchQueue.main.async {
                self.potInfo = potInfo
                self.updateTimeRemaining()
                self.startTimer()
            }
            
            self.loadParticipants(potId: potId, userId: userId, potInfo: potInfo)
        }
    }
    
    private func loadParticipants(potId: String, userId: String, potInfo: PotInfo) {
        db.collection("global_pots")
            .document(potId)
            .collection("participants")
            .order(by: "total_stars", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to load participants: \(error.localizedDescription)"
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
                
                // Calculate ranks and positions with tie handling
                var participants: [LeaderboardParticipant] = []
                var currentRank = 1
                var currentPosition = 1
                var lastStarCount: Int?
                var tiedGroups: [Int: [LeaderboardParticipant]] = [:]  // rank -> participants
                
                for (index, doc) in documents.enumerated() {
                    let data = doc.data()
                    let stars = data["total_stars"] as? Int ?? 0
                    let participantUserId = data["user_id"] as? String ?? ""
                    
                    // Update rank if stars changed
                    if let last = lastStarCount, stars < last {
                        currentRank = index + 1
                    }
                    lastStarCount = stars
                    
                    let participant = LeaderboardParticipant(
                        id: doc.documentID,
                        userId: participantUserId,
                        username: "",  // Will fetch dynamically
                        profilePictureUrl: nil,
                        totalStars: stars,
                        rank: currentRank,
                        position: currentPosition,
                        isCurrentUser: participantUserId == userId
                    )
                    
                    participants.append(participant)
                    
                    // Track tied groups for prize calculation
                    if tiedGroups[currentRank] == nil {
                        tiedGroups[currentRank] = []
                    }
                    tiedGroups[currentRank]?.append(participant)
                    
                    currentPosition += 1
                    
                    // Track current user's stats (position will be set after participant is added to array)
                    if participantUserId == userId {
                        let tiedCount = tiedGroups[currentRank]?.count ?? 1
                        let prize = self.calculatePrizeForRank(rank: currentRank, tiedCount: tiedCount, potInfo: potInfo)
                        
                        DispatchQueue.main.async {
                            self.userStars = stars
                            self.userRank = currentRank
                            self.userPrize = prize
                            // userPosition will be set from the participant object
                        }
                    }
                }
                
                // Calculate total prize pool
                let totalPool = self.calculateTotalPrizePool(tiedGroups: tiedGroups, potInfo: potInfo)
                DispatchQueue.main.async {
                    self.totalPrizePool = totalPool
                }
                
                // Fetch usernames and profile pictures
                self.fetchUserData(for: Array(participants.prefix(50)), tiedGroups: tiedGroups, potInfo: potInfo) { updatedParticipants in
                    DispatchQueue.main.async {
                        self.participants = updatedParticipants
                        self.isLoading = false
                    }
                }
            }
    }
    
    private func fetchUserData(for participants: [LeaderboardParticipant], tiedGroups: [Int: [LeaderboardParticipant]], potInfo: PotInfo, completion: @escaping ([LeaderboardParticipant]) -> Void) {
        let group = DispatchGroup()
        var updatedParticipants = participants
        
        for (index, participant) in participants.enumerated() {
            group.enter()
            
            db.collection("users").document(participant.userId).getDocument { document, error in
                if let data = document?.data() {
                    let username = data["name"] as? String ?? "Unknown"  // Changed from "username"
                    let profilePictureUrl = data["profilePictureUrl"] as? String
                    
                    // Calculate prize with tie splitting
                    let tiedCount = tiedGroups[participant.rank]?.count ?? 1
                    let prize = self.calculatePrizeForRank(rank: participant.rank, tiedCount: tiedCount, potInfo: potInfo)
                    
                    updatedParticipants[index] = LeaderboardParticipant(
                        id: participant.id,
                        userId: participant.userId,
                        username: username,
                        profilePictureUrl: profilePictureUrl,
                        totalStars: participant.totalStars,
                        rank: participant.rank,
                        position: participant.position,
                        prize: prize,
                        isCurrentUser: participant.isCurrentUser
                    )
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Set userPosition from actual participant in array
            if let currentUser = updatedParticipants.first(where: { $0.isCurrentUser }) {
                self.userPosition = currentUser.position
            }
            completion(updatedParticipants)
        }
    }
    
    private func calculatePrizeForRank(rank: Int, tiedCount: Int, potInfo: PotInfo) -> Double {
        guard rank > 0 else { return 0.0 }
        
        // Calculate base prize for this rank using integer math (cents)
        let basePrizeCents: Int
        if potInfo.decayRate == 0.0 {
            basePrizeCents = rank == 1 ? Int(potInfo.firstPlacePrize * 100) : 0
        } else {
            let prizeCents = Int(floor(potInfo.firstPlacePrize * 100 * pow(potInfo.decayRate, Double(rank - 1))))
            basePrizeCents = prizeCents < Int(potInfo.minPayout * 100) ? 0 : prizeCents
        }
        
        // Split prize among tied players (in cents)
        let splitPrizeCents = basePrizeCents / tiedCount
        
        // Convert back to dollars
        return Double(splitPrizeCents) / 100.0
    }
    
    private func calculateTotalPrizePool(tiedGroups: [Int: [LeaderboardParticipant]], potInfo: PotInfo) -> Double {
        var totalCents = 0
        
        for (rank, participants) in tiedGroups {
            let tiedCount = participants.count
            let prizePerPerson = calculatePrizeForRank(rank: rank, tiedCount: tiedCount, potInfo: potInfo)
            totalCents += Int(prizePerPerson * 100) * tiedCount
        }
        
        return Double(totalCents) / 100.0
    }
    
    // Public method to get prize for a participant (used in UI)
    func getPrizeForParticipant(_ participant: LeaderboardParticipant) -> Double {
        return participant.prize
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeRemaining()
        }
    }
    
    private func updateTimeRemaining() {
        guard let endDate = potInfo?.endDate else { return }
        
        let now = Date()
        
        if now >= endDate {
            timeRemaining = "Ended"
            potEnded = true
            timer?.invalidate()
            return
        }
        
        let timeInterval = endDate.timeIntervalSince(now)
        let days = Int(timeInterval) / 86400
        let hours = Int(timeInterval) / 3600 % 24
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if days > 0 {
            timeRemaining = "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            timeRemaining = "\(hours)h \(minutes)m"
        } else {
            timeRemaining = "\(minutes)m \(seconds)s"
        }
    }
    
    func refresh() async {
        await MainActor.run {
            loadLeaderboard()
        }
    }
}

// MARK: - Models

struct PotInfo {
    let potId: String
    let endDate: Date
    let firstPlacePrize: Double
    let maxParticipants: Int
    let decayRate: Double
    let minPayout: Double
}

struct LeaderboardParticipant: Identifiable {
    let id: String
    let userId: String
    let username: String
    let profilePictureUrl: String?
    let totalStars: Int
    let rank: Int  // For prize calculation (1, 1, 3, 4, 4)
    let position: Int  // For display (1, 2, 3, 4, 5)
    var prize: Double = 0.0  // Prize for this participant (split if tied)
    let isCurrentUser: Bool
}

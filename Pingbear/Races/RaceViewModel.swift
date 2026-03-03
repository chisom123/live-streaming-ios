import Foundation
import FirebaseFirestore
import FirebaseAuth

class RaceViewModel: ObservableObject {
    @Published var raceInfo: RaceInfo?
    @Published var participants: [RaceParticipantDisplay] = []
    @Published var isLoading = false
    @Published var timeRemaining = ""
    @Published var raceEnded = false
    @Published var hasActiveRace = false
    
    private let db = Firestore.firestore()
    private var timer: Timer?
    private var raceListener: ListenerRegistration?
    private var participantsListener: ListenerRegistration?
    
    deinit {
        stopListening()
    }
    
    // MARK: - Load Race
    
    func loadRace(competitionId: String) {
        isLoading = true
        
        // Use real-time listener so points pool and stars update live
        raceListener?.remove()
        raceListener = db.collection("competition_races")
            .whereField("competition_id", isEqualTo: competitionId)
            .whereField("status", isEqualTo: "active")
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("RaceViewModel: Error listening to race: \(error)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.hasActiveRace = false
                    }
                    return
                }
                
                guard let doc = snapshot?.documents.first,
                      let endDate = (doc.data()["end_date"] as? Timestamp)?.dateValue(),
                      Date() < endDate else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.hasActiveRace = false
                        self.raceInfo = nil
                        self.participants = []
                    }
                    return
                }
                
                let data = doc.data()
                let race = RaceInfo(
                    raceId: doc.documentID,
                    competitionId: competitionId,
                    endDate: endDate,
                    participantCount: data["participant_count"] as? Int ?? 0,
                    pointsPool: data["points_pool"] as? Int ?? 0,
                    totalStars: data["total_stars"] as? Int ?? 0
                )
                
                DispatchQueue.main.async {
                    self.raceInfo = race
                    self.hasActiveRace = true
                    self.isLoading = false
                    self.startTimer()
                }
                
                // Load participants whenever race updates
                self.listenToParticipants(raceId: doc.documentID)
            }
    }
    
    // MARK: - Listen To Participants
    
    private func listenToParticipants(raceId: String) {
        participantsListener?.remove()
        participantsListener = db.collection("competition_races")
            .document(raceId)
            .collection("race_participants")
            .order(by: "total_stars", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("RaceViewModel: Error listening to participants: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let rawParticipants = documents.map { doc -> (userId: String, stars: Int) in
                    let data = doc.data()
                    return (
                        userId: doc.documentID,
                        stars: data["total_stars"] as? Int ?? 0
                    )
                }
                
                // Fetch user data for participants
                self.fetchUserData(for: rawParticipants)
            }
    }
    
    // MARK: - Fetch User Data
    
    private func fetchUserData(for rawParticipants: [(userId: String, stars: Int)]) {
        guard !rawParticipants.isEmpty else {
            DispatchQueue.main.async {
                self.participants = []
            }
            return
        }
        
        let group = DispatchGroup()
        var displayParticipants: [RaceParticipantDisplay] = []
        let currentUserId = Auth.auth().currentUser?.uid
        let totalStars = rawParticipants.reduce(0) { $0 + $1.stars }
        let pointsPool = raceInfo?.pointsPool ?? 0
        
        for participant in rawParticipants {
            group.enter()
            
            db.collection("users").document(participant.userId).getDocument { document, error in
                let data = document?.data()
                let username = data?["name"] as? String ?? "Unknown"
                let profilePictureUrl = data?["profilePictureUrl"] as? String
                let isCurrentUser = participant.userId == currentUserId
                
                // Calculate projected points
                let projectedPoints: Int
                if totalStars > 0 {
                    projectedPoints = Int(Double(participant.stars) / Double(totalStars) * Double(pointsPool))
                } else {
                    projectedPoints = 0
                }
                
                let display = RaceParticipantDisplay(
                    userId: participant.userId,
                    username: isCurrentUser ? "Me" : username,
                    profilePictureUrl: profilePictureUrl,
                    totalStars: participant.stars,
                    projectedPoints: projectedPoints,
                    isCurrentUser: isCurrentUser
                )
                
                displayParticipants.append(display)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Sort by stars descending
            self.participants = displayParticipants.sorted { $0.totalStars > $1.totalStars }
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeRemaining()
        }
        updateTimeRemaining()
    }
    
    private func updateTimeRemaining() {
        guard let endDate = raceInfo?.endDate else { return }
        
        let now = Date()
        
        if now >= endDate {
            timeRemaining = "--"
            raceEnded = true
            timer?.invalidate()
            return
        }
        
        let timeInterval = endDate.timeIntervalSince(now)
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            timeRemaining = "\(hours)h \(minutes)m"
        } else {
            timeRemaining = "\(minutes)m \(seconds)s"
        }
    }
    
    // MARK: - Cleanup
    
    func stopListening() {
        timer?.invalidate()
        raceListener?.remove()
        participantsListener?.remove()
    }
}

// MARK: - Display Model

struct RaceParticipantDisplay: Identifiable {
    let id = UUID()
    let userId: String
    let username: String
    let profilePictureUrl: String?
    let totalStars: Int
    let projectedPoints: Int
    let isCurrentUser: Bool
}

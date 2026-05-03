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

    deinit { stopListening() }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Load Race
    // ─────────────────────────────────────────────────────────────

    func loadRace(competitionId: String) {
        isLoading = true

        raceListener?.remove()
        raceListener = db.collection("competition_races")
            .whereField("competition_id", isEqualTo: competitionId)
            .whereField("status", isEqualTo: "active")
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("RaceViewModel: Error: \(error)")
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
                    raceId:           doc.documentID,
                    competitionId:    competitionId,
                    duration:         data["duration"] as? String ?? "weekly",
                    endDate:          endDate,
                    participantCount: data["participant_count"] as? Int ?? 0,
                    totalPot:         data["total_pot"] as? Double ?? 0.0,
                    totalStars:       data["total_stars"] as? Int ?? 0
                )

                DispatchQueue.main.async {
                    self.raceInfo = race
                    self.hasActiveRace = true
                    self.isLoading = false
                    self.startTimer()
                }

                self.listenToParticipants(raceId: doc.documentID)
            }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Listen To Participants
    // ─────────────────────────────────────────────────────────────

    private func listenToParticipants(raceId: String) {
        participantsListener?.remove()
        participantsListener = db.collection("competition_races")
            .document(raceId)
            .collection("race_participants")
            .order(by: "total_stars", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("RaceViewModel: Participants error: \(error)")
                    return
                }
                guard let documents = snapshot?.documents else { return }

                let raw = documents.map { doc -> (userId: String, stars: Int) in
                    (userId: doc.documentID, stars: doc.data()["total_stars"] as? Int ?? 0)
                }
                self.fetchUserData(for: raw)
            }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Fetch User Data
    // ─────────────────────────────────────────────────────────────

    private func fetchUserData(for rawParticipants: [(userId: String, stars: Int)]) {
        guard !rawParticipants.isEmpty else {
            DispatchQueue.main.async { self.participants = [] }
            return
        }

        let group = DispatchGroup()
        var displayParticipants: [RaceParticipantDisplay] = []
        let currentUserId = Auth.auth().currentUser?.uid
        let totalStars = rawParticipants.reduce(0) { $0 + $1.stars }
        let totalPot = raceInfo?.totalPot ?? 0.0

        for participant in rawParticipants {
            group.enter()
            db.collection("users").document(participant.userId).getDocument { doc, _ in
                let data = doc?.data()
                let username = data?["name"] as? String ?? "Unknown"
                let profilePictureUrl = data?["profilePictureUrl"] as? String
                let isCurrentUser = participant.userId == currentUserId

                // Projected payout in dollars based on current star share
                let projectedPayout: Double
                if totalStars > 0 && totalPot > 0 {
                    projectedPayout = (Double(participant.stars) / Double(totalStars)) * totalPot
                } else {
                    projectedPayout = 0.0
                }

                displayParticipants.append(RaceParticipantDisplay(
                    userId:            participant.userId,
                    username:          isCurrentUser ? "Me" : username,
                    profilePictureUrl: profilePictureUrl,
                    totalStars:        participant.stars,
                    projectedPayout:   projectedPayout,
                    isCurrentUser:     isCurrentUser
                ))
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.participants = displayParticipants.sorted { $0.totalStars > $1.totalStars }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Timer
    // ─────────────────────────────────────────────────────────────

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

        let interval = endDate.timeIntervalSince(now)
        let days    = Int(interval) / 86400
        let hours   = Int(interval) / 3600 % 24
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60

        if days > 0 {
            timeRemaining = "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            timeRemaining = "\(hours)h \(minutes)m"
        } else {
            timeRemaining = "\(minutes)m \(seconds)s"
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Cleanup
    // ─────────────────────────────────────────────────────────────

    func stopListening() {
        timer?.invalidate()
        raceListener?.remove()
        participantsListener?.remove()
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Display Model
// ─────────────────────────────────────────────────────────────

struct RaceParticipantDisplay: Identifiable {
    let id               = UUID()
    let userId:           String
    let username:         String
    let profilePictureUrl: String?
    let totalStars:       Int
    let projectedPayout:  Double   // estimated winnings in USD
    let isCurrentUser:    Bool
}

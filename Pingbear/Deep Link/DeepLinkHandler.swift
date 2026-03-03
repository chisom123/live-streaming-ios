import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

enum DeepLinkType: Equatable {
    case competition(String)
    case redeem(String)
    case unknown
}

class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()
    
    @Published var pendingDeepLink: DeepLinkType?
    @Published var isProcessingDeepLink = false
    @Published var pendingRedeemCode: String? = nil
    
    private let db = Firestore.firestore()
    private var deepLinkQueue: [URL] = []
    private var isProcessingQueue = false
    private var retryTimer: Timer?
    
    private init() {
        setupAppStateObservers()
    }
    
    // MARK: - App State Management
    private func setupAppStateObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        print("App became active - processing queued deep links")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.processQueue()
        }
    }
    
    @objc private func appWillResignActive() {
        print("App will resign active")
        retryTimer?.invalidate()
    }
    
    // MARK: - Enhanced URL Handling
    func handleURL(_ url: URL) {
        print("DeepLinkHandler: Received URL: \(url)")
        deepLinkQueue.append(url)
        if !isProcessingQueue {
            processQueue()
        }
    }
    
    private func processQueue() {
        guard !isProcessingQueue, !deepLinkQueue.isEmpty else { return }
        
        isProcessingQueue = true
        let url = deepLinkQueue.removeFirst()
        
        print("Processing deep link from queue: \(url)")
        
        processURL(url) { [weak self] success in
            DispatchQueue.main.async {
                self?.isProcessingQueue = false
                
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.processQueue()
                    }
                } else {
                    self?.retryProcessing(url)
                }
            }
        }
    }
    
    private func processURL(_ url: URL, completion: @escaping (Bool) -> Void) {
        guard url.scheme == "socialstar" else {
            print("Invalid scheme: \(url.scheme ?? "none")")
            completion(false)
            return
        }
        
        let urlString = url.absoluteString
        
        // Handle competition deep links: socialstar://competition/<id>
        if urlString.contains("competition/") {
            let components = urlString.components(separatedBy: "competition/")
            if components.count > 1 {
                let competitionId = components[1]
                print("Found competition ID: \(competitionId)")
                pendingDeepLink = .competition(competitionId)
                completion(true)
                return
            }
        }
        
        // Handle redeem deep links: socialstar://redeem/<code>
        if urlString.contains("redeem/") {
            let components = urlString.components(separatedBy: "redeem/")
            if components.count > 1 {
                let code = components[1]
                print("Found redeem code: \(code)")
                pendingDeepLink = .redeem(code)
                completion(true)
                return
            }
        }
        
        print("URL doesn't match any known deep link path")
        pendingDeepLink = .unknown
        completion(false)
    }
    
    // MARK: - Retry Logic
    private func retryProcessing(_ url: URL, retryCount: Int = 0) {
        guard retryCount < 3 else {
            print("Failed to process deep link after 3 attempts")
            DispatchQueue.main.async { [weak self] in
                self?.processQueue()
            }
            return
        }
        
        let delay = pow(2.0, Double(retryCount))
        
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            print("Retrying deep link processing (attempt \(retryCount + 1))")
            self?.processURL(url) { success in
                if !success {
                    self?.retryProcessing(url, retryCount: retryCount + 1)
                } else {
                    DispatchQueue.main.async {
                        self?.processQueue()
                    }
                }
            }
        }
    }
    
    // MARK: - Enhanced Processing
    func processPendingDeepLink(completion: @escaping (Competition?) -> Void) {
        guard let deepLink = pendingDeepLink else {
            print("No pending deep link")
            completion(nil)
            return
        }
        
        print("Processing deep link: \(deepLink)")
        
        DispatchQueue.main.async { [weak self] in
            self?.isProcessingDeepLink = true
            
            switch deepLink {
            case .competition(let competitionId):
                self?.processCompetitionDeepLink(competitionId: competitionId) { competition in
                    DispatchQueue.main.async {
                        self?.isProcessingDeepLink = false
                        self?.pendingDeepLink = nil
                        completion(competition)
                    }
                }
                
            case .redeem(let code):
                // Surface the code via pendingRedeemCode so PingbearApp can present RedeemWinCodeView
                self?.pendingRedeemCode = code
                self?.isProcessingDeepLink = false
                self?.pendingDeepLink = nil
                completion(nil)
                
            case .unknown:
                self?.isProcessingDeepLink = false
                self?.pendingDeepLink = nil
                completion(nil)
            }
        }
    }
    
    private func processCompetitionDeepLink(competitionId: String, completion: @escaping (Competition?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No authenticated user")
            completion(nil)
            return
        }
        
        print("Processing competition deep link for competition: \(competitionId)")
        
        let competitionRef = db.collection("competitions").document(competitionId)
        
        competitionRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching competition: \(error)")
                completion(nil)
                return
            }
            
            guard let data = snapshot?.data(),
                  snapshot?.exists == true else {
                print("Competition doesn't exist")
                completion(nil)
                return
            }
            
            print("Competition found: \(data)")
            
            let competition = Competition(
                id: competitionId,
                description: data["description"] as? String ?? "Competition",
                date: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            )
            
            let memberRef = competitionRef.collection("members").document(userId)
            
            memberRef.getDocument { [weak self] memberSnapshot, memberError in
                guard let self = self else { return }
                
                if memberSnapshot?.exists == true {
                    print("User is already a member")
                    completion(competition)
                } else {
                    print("Adding user as member")
                    self.addUserToCompetition(userId: userId, competitionId: competitionId) { success in
                        if success {
                            print("Successfully added user to competition")
                            completion(competition)
                        } else {
                            print("Failed to add user to competition")
                            completion(nil)
                        }
                    }
                }
            }
        }
    }
    
    private func addUserToCompetition(userId: String, competitionId: String, completion: @escaping (Bool) -> Void) {
        print("Adding user \(userId) to competition \(competitionId)")
        
        let memberRef = db.collection("competitions").document(competitionId)
            .collection("members").document(userId)
        
        memberRef.setData([
            "userId": userId,
            "coins": 150
        ]) { [weak self] error in
            if let error = error {
                print("Error adding member: \(error)")
                completion(false)
                return
            }
            
            let groupMembershipRef = self?.db.collection("groupMemberships").document(userId)
                .collection("competitions").document(competitionId)
            
            groupMembershipRef?.setData(["competitionId": competitionId]) { error in
                if let error = error {
                    print("Error adding group membership: \(error)")
                    completion(false)
                } else {
                    print("Successfully added user to competition")
                    Analytics.shared.trackCompetition(
                        action: "joined_via_deeplink",
                        competitionId: competitionId
                    )
                    
                    self?.db.collection("users").document(userId).getDocument { userDoc, userError in
                        let newMemberName = userDoc?.data()?["name"] as? String ?? "Someone"
                        
                        self?.db.collection("competitions").document(competitionId).getDocument { compDoc, _ in
                            let competitionDescription = compDoc?.data()?["description"] as? String ?? "Competition"
                            
                            NotificationQueueManager.shared.queueGroupNotification(
                                competitionId: competitionId,
                                title: competitionDescription,
                                body: "\(newMemberName) joined the competition",
                                senderId: userId,
                                excludeUsers: [userId]
                            )
                            
                            NotificationQueueManager.shared.processQueuedNotifications()
                        }
                    }
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshCompetitions"), object: nil)
                    }
                    
                    completion(true)
                }
            }
        }
    }
    
    func createShareableLink(for competitionId: String) -> String {
        return "https://socialstarapp.com/join/\(competitionId)"
    }
    
    // MARK: - Cleanup
    func reset() {
        deepLinkQueue.removeAll()
        pendingDeepLink = nil
        pendingRedeemCode = nil
        isProcessingDeepLink = false
        isProcessingQueue = false
        retryTimer?.invalidate()
    }
}

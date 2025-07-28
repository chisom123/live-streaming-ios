import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

enum DeepLinkType: Equatable {
    case competition(String)
    case unknown
}

class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()
    
    @Published var pendingDeepLink: DeepLinkType?
    @Published var isProcessingDeepLink = false
    
    private let db = Firestore.firestore()
    private var deepLinkQueue: [URL] = []
    private var isProcessingQueue = false
    private var retryTimer: Timer?
    
    private init() {
        setupAppStateObservers()
    }
    
    // MARK: - App State Management
    private func setupAppStateObservers() {
        // Monitor app state changes
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
        // Process any queued deep links when app becomes active
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.processQueue()
        }
    }
    
    @objc private func appWillResignActive() {
        print("App will resign active")
        // Cancel any pending processing
        retryTimer?.invalidate()
    }
    
    // MARK: - Enhanced URL Handling
    func handleURL(_ url: URL) {
        print("DeepLinkHandler: Received URL: \(url)")
        
        // Add to queue instead of processing immediately
        deepLinkQueue.append(url)
        
        // Process queue if not already processing
        if !isProcessingQueue {
            processQueue()
        }
    }
    
    private func processQueue() {
        guard !isProcessingQueue, !deepLinkQueue.isEmpty else { return }
        
        isProcessingQueue = true
        let url = deepLinkQueue.removeFirst()
        
        print("Processing deep link from queue: \(url)")
        
        // Parse and process the URL
        processURL(url) { [weak self] success in
            DispatchQueue.main.async {
                self?.isProcessingQueue = false
                
                if success {
                    // Continue processing queue after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.processQueue()
                    }
                } else {
                    // Retry with exponential backoff
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
        
        print("URL doesn't contain competition path")
        pendingDeepLink = .unknown
        completion(false)
    }
    
    // MARK: - Retry Logic
    private func retryProcessing(_ url: URL, retryCount: Int = 0) {
        guard retryCount < 3 else {
            print("Failed to process deep link after 3 attempts")
            // Continue with next item in queue
            DispatchQueue.main.async { [weak self] in
                self?.processQueue()
            }
            return
        }
        
        let delay = pow(2.0, Double(retryCount)) // Exponential backoff: 1s, 2s, 4s
        
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
        
        // Ensure we're on main thread and UI is ready
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
        
        // First check if the competition exists
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
            
            // Create competition object
            let competition = Competition(
                id: competitionId,
                description: data["description"] as? String ?? "Competition",
                date: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            )
            
            // Check if user is already a member
            let memberRef = competitionRef.collection("members").document(userId)
            
            memberRef.getDocument { [weak self] memberSnapshot, memberError in
                guard let self = self else { return }
                
                if memberSnapshot?.exists == true {
                    // User is already a member, just open the competition
                    print("User is already a member")
                    completion(competition)
                } else {
                    // Add user as a member
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
        
        // First add to members collection to satisfy security rules
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
            
            // Now add to groupMemberships
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
                    
                    // Trigger refresh of competitions list
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
        isProcessingDeepLink = false
        isProcessingQueue = false
        retryTimer?.invalidate()
    }
}

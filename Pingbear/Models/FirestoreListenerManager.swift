import Foundation
import Firebase
import FirebaseFirestore

class FirestoreListenerManager {
    static let shared = FirestoreListenerManager()
    private var listenerRegistrations: [String: ListenerRegistration] = [:]
    private var debounceWorkItems: [String: DispatchWorkItem] = [:]  // For managing debouncing

    private init() {}

    func addListener(for path: String, debounceInterval: TimeInterval = 0, processChanges: @escaping ([DocumentChange]) -> Void) {
        // Remove existing listener and debounce work item if they exist
        removeListener(for: path)
        
        let db = Firestore.firestore()
        let registration = db.collection(path).addSnapshotListener { [weak self] snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                print("Listener error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            // Cancel previous work item if it exists
            self?.debounceWorkItems[path]?.cancel()
            
            // Create a new work item
            let workItem = DispatchWorkItem {
                processChanges(snapshot.documentChanges)
            }
            
            // Save the new work item
            self?.debounceWorkItems[path] = workItem
            
            // Execute work item after specified delay
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
        }

        listenerRegistrations[path] = registration
    }
    
    // New method for query-based listeners
    func addQueryListener(for query: Query, path: String, debounceInterval: TimeInterval = 0, processChanges: @escaping ([DocumentChange]) -> Void) {
        removeListener(for: path)
        
        let registration = query.addSnapshotListener { [weak self] snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                print("Listener error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            self?.debounceWorkItems[path]?.cancel()
            
            let workItem = DispatchWorkItem {
                processChanges(snapshot.documentChanges)
            }
            
            self?.debounceWorkItems[path] = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
        }

        listenerRegistrations[path] = registration
    }

    func removeListener(for path: String) {
        listenerRegistrations[path]?.remove()
        listenerRegistrations.removeValue(forKey: path)
        debounceWorkItems[path]?.cancel()
        debounceWorkItems.removeValue(forKey: path)
    }
    
    func removeAllListeners() {
        for path in listenerRegistrations.keys {
            removeListener(for: path)
        }
    }
}

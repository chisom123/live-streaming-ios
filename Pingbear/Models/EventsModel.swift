import FirebaseFirestore

class Event: Competition {
    @Published var location: String
    @Published var startDateTime: Date
    @Published var endDateTime: Date?
    
    init(id: String,
         description: String,
         startDateTime: Date,
         endDateTime: Date? = nil,
         location: String,
         isEvent: Bool = true) {
        self.location = location
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        super.init(id: id, description: description, date: startDateTime, isEvent: isEvent)
    }
}

class EventsModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var filteredEvents: [Event] = []
    
    private let db = Firestore.firestore()
    
    func fetchPublicEvents() async {
        return await withCheckedContinuation { continuation in
            // Get all event IDs first
            db.collection("events").getDocuments { [weak self] (snapshot, error) in
                if let error = error {
                    print("Error fetching events: \(error)")
                    continuation.resume()
                    return
                }
                
                let eventIds = snapshot?.documents.map { $0.documentID } ?? []
                
                if !eventIds.isEmpty {
                    self?.batchFetchEvents(ids: eventIds) {
                        continuation.resume()
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    private func batchFetchEvents(ids: [String], completion: @escaping () -> Void) {
        let group = DispatchGroup()
        
        // Variables to store results from parallel queries
        var competitionDocs: [QueryDocumentSnapshot]?
        var eventMetadata: [String: (location: String, startDateTime: Timestamp?, endDateTime: Timestamp?)] = [:]
        
        // Fetch competitions in parallel
        group.enter()
        db.collection("competitions")
            .whereField(FieldPath.documentID(), in: ids)
            .getDocuments { (snapshot, error) in
                defer { group.leave() }
                if let error = error {
                    print("Error batch fetching competitions: \(error)")
                    return
                }
                competitionDocs = snapshot?.documents
            }
        
        // Fetch event metadata in parallel
        group.enter()
        db.collection("events")
            .whereField(FieldPath.documentID(), in: ids)
            .getDocuments { (eventSnapshot, error) in
                defer { group.leave() }
                if let error = error {
                    print("Error fetching event metadata: \(error)")
                    return
                }
                
                eventMetadata = Dictionary(
                    uniqueKeysWithValues: eventSnapshot?.documents.map { doc in
                        let data = doc.data()
                        return (doc.documentID, (
                            location: data["location"] as? String ?? "",
                            startDateTime: data["startDateTime"] as? Timestamp,
                            endDateTime: data["endDateTime"] as? Timestamp
                        ))
                    } ?? []
                )
            }
        
        // Process results after both queries complete
        group.notify(queue: .global()) { [weak self] in
            guard let documents = competitionDocs else {
                completion()
                return
            }
            
            let events = documents.compactMap { doc -> Event? in
                let data = doc.data()
                guard let metadata = eventMetadata[doc.documentID] else { return nil }
                
                return Event(
                    id: doc.documentID,
                    description: data["description"] as? String ?? "No Description",
                    startDateTime: metadata.startDateTime?.dateValue() ?? Date(),
                    endDateTime: metadata.endDateTime?.dateValue(),
                    location: metadata.location
                )
            }
            
            DispatchQueue.main.async {
                self?.events = events
                completion()
            }
        }
    }
}

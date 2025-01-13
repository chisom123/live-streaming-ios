import FirebaseFirestore

class Event: Competition {
    @Published var location: String
    @Published var image: String
    @Published var startDateTime: Date
    @Published var endDateTime: Date?
    @Published var ticketUrl: String?
    
    init(id: String,
         description: String,
         startDateTime: Date,
         endDateTime: Date? = nil,
         location: String,
         image: String,
         ticketUrl: String? = nil,
         isEvent: Bool = true) {
        self.location = location
        self.image = image
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.ticketUrl = ticketUrl
        super.init(id: id, description: description, date: startDateTime, isEvent: isEvent)
    }
}

class EventsModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var filteredEvents: [Event] = []
    
    private let db = Firestore.firestore()
    
    func fetchPublicEvents(completion: (() -> Void)? = nil) {
        // Get all event IDs first
        db.collection("events").getDocuments { [weak self] (snapshot, error) in
            if let error = error {
                print("Error fetching events: \(error)")
                completion?()
                return
            }
            
            let eventIds = snapshot?.documents.map { $0.documentID } ?? []
            
            if !eventIds.isEmpty {
                self?.batchFetchEvents(ids: eventIds) {
                    completion?()
                }
            } else {
                completion?()
            }
        }
    }
    
    func filterUpcomingEvents() {
        let now = Date()
        let twentyFourHoursLater = Calendar.current.date(byAdding: .hour, value: 24, to: now)!
        
        filteredEvents = events.filter { event in
            // Check if the event starts within the next 24 hours
            guard event.startDateTime <= twentyFourHoursLater else { return false }
            
            // If the event has an end time, check if it's still ongoing
            if let endDateTime = event.endDateTime {
                return now <= endDateTime
            }
            
            // If no end time, just check if the event is in the future
            return now <= event.startDateTime
        }
        .sorted { $0.startDateTime < $1.startDateTime }
    }
    
    private func batchFetchEvents(ids: [String], completion: @escaping () -> Void) {
        let group = DispatchGroup()
        
        // Variables to store results from parallel queries
        var competitionDocs: [QueryDocumentSnapshot]?
        var eventMetadata: [String: (location: String, image: String, startDateTime: Timestamp?, endDateTime: Timestamp?, ticketUrl: String?)] = [:]
        
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
                            image: data["image"] as? String ?? "",
                            startDateTime: data["startDateTime"] as? Timestamp,
                            endDateTime: data["endDateTime"] as? Timestamp,
                            ticketUrl: data["ticketUrl"] as? String
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
                    location: metadata.location,
                    image: metadata.image,
                    ticketUrl: metadata.ticketUrl
                )
            }
            
            DispatchQueue.main.async {
                self?.events = events
                self?.filterUpcomingEvents()
                completion()
            }
        }
    }
}

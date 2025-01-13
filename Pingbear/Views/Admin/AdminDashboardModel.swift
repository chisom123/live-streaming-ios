import FirebaseFirestore

class AdminDashboardModel: EventsModel {
    private let db = Firestore.firestore()
    
    // Just add the admin-specific functions
    func createEvent(description: String, location: String, image: String, startDate: Date, endDate: Date?, ticketUrl: String?) {
        let eventRef = db.collection("events").document()
        let competitionRef = db.collection("competitions").document(eventRef.documentID)
        
        let batch = db.batch()
        
        var eventData: [String: Any] = [
            "location": location,
            "image": image,
            "startDateTime": Timestamp(date: startDate)
        ]
        
        if let endDate = endDate {
            eventData["endDateTime"] = Timestamp(date: endDate)
        }
        
        if let ticketUrl = ticketUrl {
            eventData["ticketUrl"] = ticketUrl
        }
        
        let competitionData: [String: Any] = [
            "description": description,
            "timestamp": Timestamp(date: Date())  // Current date/time
        ]
        
        batch.setData(eventData, forDocument: eventRef)
        batch.setData(competitionData, forDocument: competitionRef)
        
        batch.commit { [weak self] error in
            if let error = error {
                print("Error creating event: \(error)")
            } else {
                self?.fetchPublicEvents()
            }
        }
    }
    
    func deleteEvent(eventId: String) {
        let batch = db.batch()
        
        batch.deleteDocument(db.collection("events").document(eventId))
        batch.deleteDocument(db.collection("competitions").document(eventId))
        
        batch.commit { [weak self] error in
            if let error = error {
                print("Error deleting event: \(error)")
            } else {
                self?.fetchPublicEvents()  // Use the inherited method
            }
        }
    }
    
    func updateEvent(eventId: String, description: String, location: String, image: String, startDate: Date, endDate: Date?, ticketUrl: String?) {
        let batch = db.batch()
        
        var eventData: [String: Any] = [
            "location": location,
            "image": image,
            "startDateTime": Timestamp(date: startDate)
        ]
        
        if let endDate = endDate {
            eventData["endDateTime"] = Timestamp(date: endDate)
        }
        
        if let ticketUrl = ticketUrl {
            eventData["ticketUrl"] = ticketUrl
        }
        
        let competitionData: [String: Any] = [
            "description": description
        ]
        
        batch.updateData(eventData, forDocument: db.collection("events").document(eventId))
        batch.updateData(competitionData, forDocument: db.collection("competitions").document(eventId))
        
        batch.commit { [weak self] error in
            if let error = error {
                print("Error updating event: \(error)")
            } else {
                self?.fetchPublicEvents()
            }
        }
    }
}

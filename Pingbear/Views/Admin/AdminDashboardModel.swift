import FirebaseFirestore

class AdminDashboardModel: EventsModel {
    private let db = Firestore.firestore()
    
    // Just add the admin-specific functions
    func createEvent(description: String, location: String, startDate: Date, endDate: Date?) {
        let eventRef = db.collection("events").document()
        let competitionRef = db.collection("competitions").document(eventRef.documentID)
        
        let batch = db.batch()
        
        var eventData: [String: Any] = [
            "location": location,
            "startDateTime": Timestamp(date: startDate)
        ]
        
        if let endDate = endDate {
            eventData["endDateTime"] = Timestamp(date: endDate)
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
                Task { [weak self] in
                    await self?.fetchPublicEvents()
                }
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
                Task { [weak self] in
                    await self?.fetchPublicEvents()
                }
            }
        }
    }
    
    func updateEvent(eventId: String, description: String, location: String, startDate: Date, endDate: Date?) {
        let batch = db.batch()
        
        var eventData: [String: Any] = [
            "location": location,
            "startDateTime": Timestamp(date: startDate)
        ]
        
        if let endDate = endDate {
            eventData["endDateTime"] = Timestamp(date: endDate)
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
                Task { [weak self] in
                    await self?.fetchPublicEvents()
                }
            }
        }
    }
}

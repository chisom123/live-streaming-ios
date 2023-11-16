import SwiftUI
import Firebase
import FirebaseFirestore
import CoreLocation

struct Competition: Identifiable {
    let id: String
    let description: String
    let date: Date
    let latitude: Double
    let longitude: Double
    var locationName: String?  // Mutable and optionals
}

class CompetitionsModel: ObservableObject {
    @Published var competitions: [Competition] = []

    init() {
        fetchCompetitions()
    }

    func fetchCompetitions() {
        let db = Firestore.firestore()

        db.collection("competitions")
            .whereField("timestamp", isGreaterThan: Timestamp(date: Calendar.current.date(byAdding: .hour, value: -24, to: Date())!))
            .getDocuments { [weak self] (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    var fetchedCompetitions = querySnapshot?.documents.compactMap { document -> Competition? in
                        let data = document.data()
                        guard let description = data["description"] as? String,
                              let timestamp = data["timestamp"] as? Timestamp,
                              let latitude = data["latitude"] as? Double,
                              let longitude = data["longitude"] as? Double else {
                                  return nil
                        }

                        return Competition(
                            id: document.documentID,
                            description: description,
                            date: timestamp.dateValue(),
                            latitude: latitude,
                            longitude: longitude,
                            locationName: nil
                        )
                    } ?? []

                    // Geocoding after fetching competitions
                    for index in fetchedCompetitions.indices {
                        let geocoder = CLGeocoder()
                        let location = CLLocation(latitude: fetchedCompetitions[index].latitude, longitude: fetchedCompetitions[index].longitude)

                        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
                            if let placemark = placemarks?.first {
                                let locationName = "\(placemark.locality ?? ""), \(placemark.country ?? "")"
                                DispatchQueue.main.async {
                                    fetchedCompetitions[index].locationName = locationName
                                    self?.competitions = fetchedCompetitions
                                }
                            }
                        }
                    }
                }
            }
    }


}

import SwiftUI
import Firebase
import UIKit
import MapKit
import FirebaseFirestore
import Flurry_iOS_SDK
import CoreLocation

struct MapView: View {
    // Reduced the span for a more zoomed-in view
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02) // smaller delta means more zoom
    )

    @State private var competitionLocations = [CustomPointAnnotation]()
    @State private var selectedCompetition: CustomPointAnnotation? = nil
    
    private var locationManager = CLLocationManager()
    
    var body: some View {
        NavigationView {
            ZStack {
                Map(coordinateRegion: $region,
                    showsUserLocation: true,
                    annotationItems: competitionLocations) { location in
                        MapAnnotation(coordinate: location.coordinate) {
                            // Here, we use a Button action to handle the tap, and set the selected competition
                            Button(action: {
                                self.selectedCompetition = location
                            }) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.red)
                                    .imageScale(.large)
                            }
                        }
                    }
                .edgesIgnoringSafeArea(.top)
                .onAppear {
                    setupLocationManager()
                    fetchCompetitionLocations()
                }
                .fullScreenCover(item: $selectedCompetition) { selectedCompetition in
                    // When an annotation is tapped, this will trigger navigation to the 'CompDetails' view
                    CompDetails(competition: selectedCompetition)
                }
            }
        }
    }

    func distance(from location1: CLLocationCoordinate2D, to location2: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: location1.latitude, longitude: location1.longitude)
        let location2 = CLLocation(latitude: location2.latitude, longitude: location2.longitude)

        return location1.distance(from: location2) // returns the distance in meters
    }


    private func setupLocationManager() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        // Set the initial region to the user's current location
        if let userLocation = locationManager.location?.coordinate {
            region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }
    }

    private func fetchCompetitionLocations() {
        let db = Firestore.firestore()

        // Calculate the cutoff time, which is 12 hours before now.
        let twelveHoursAgo = Calendar.current.date(byAdding: .hour, value: -12, to: Date())!
        let twelveHoursAgoTimestamp = Timestamp(date: twelveHoursAgo)

        db.collection("competitions")
            .whereField("timestamp", isGreaterThan: twelveHoursAgoTimestamp) // This ensures we only fetch recent competitions.
            .getDocuments { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    let userLocation = self.locationManager.location?.coordinate
                    self.competitionLocations = querySnapshot?.documents.compactMap { document in
                        let data = document.data()
                        
                        if  let lat = data["latitude"] as? Double,
                            let lon = data["longitude"] as? Double,
                            let description = data["description"] as? String,
                            let timestamp = data["timestamp"] as? Timestamp { // Ensure the timestamp exists

                            let competitionLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                            
                            // Check if the competition is recent (within the last 12 hours)
                            let competitionDate = timestamp.dateValue()
                            if competitionDate >= twelveHoursAgo,
                               let userLocation = userLocation,
                               self.distance(from: userLocation, to: competitionLocation) <= 8046.72 { // About 5 miles
                                // If all conditions are met, add the competition
                                return CustomPointAnnotation(id: document.documentID, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), competitionDescription: description)
                            }
                        }
                        return nil // Ignore any data points that don't meet the criteria
                    } ?? []
                }
            }
    }

}

class CustomPointAnnotation: NSObject, MKAnnotation, Identifiable {
    let id: String // this could be the document ID from Firestore
    @objc dynamic var coordinate: CLLocationCoordinate2D

    var competitionDescription: String

    init(id: String, coordinate: CLLocationCoordinate2D, competitionDescription: String) {
        self.id = id
        self.coordinate = coordinate
        self.competitionDescription = competitionDescription
    }
}

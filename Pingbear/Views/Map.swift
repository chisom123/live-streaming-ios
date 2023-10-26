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
    
    private var locationManager = CLLocationManager()
    
    var body: some View {
        Map(coordinateRegion: $region,
            showsUserLocation: true,
            annotationItems: competitionLocations) { location in
                MapAnnotation(coordinate: location.coordinate) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.red)
                        .imageScale(.large)
                }
            }
        .edgesIgnoringSafeArea(.top)
        .onAppear {
            setupLocationManager()
            fetchCompetitionLocations()
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
        db.collection("competitions").getDocuments { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                let userLocation = locationManager.location?.coordinate
                competitionLocations = querySnapshot?.documents.compactMap { document in
                    let data = document.data()
                    if  let lat = data["latitude"] as? Double,
                        let lon = data["longitude"] as? Double {
                        let competitionLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)

                        // Check if competition location is within a 5-mile (about 8046.72 meters) radius
                        if let userLocation = userLocation,
                           distance(from: userLocation, to: competitionLocation) <= 8046.72 {
                            return CustomPointAnnotation(coordinate: competitionLocation)
                        }
                    }
                    return nil
                } ?? []
            }
        }
    }

}

class CustomPointAnnotation: NSObject, MKAnnotation, Identifiable {
    let id = UUID()
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String?

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

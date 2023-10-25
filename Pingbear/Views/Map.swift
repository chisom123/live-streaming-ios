import SwiftUI
import Firebase
import UIKit
import MapKit
import FirebaseFirestore
import Flurry_iOS_SDK
import CoreLocation

class CustomPointAnnotation: NSObject, MKAnnotation, Identifiable {
    let id = UUID() // Conform to Identifiable
    @objc dynamic var coordinate: CLLocationCoordinate2D // Required by MKAnnotation
    var title: String? // Optional - you can add additional data if needed

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

struct MapView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )
    
    // Corrected to use CustomPointAnnotation
    @State private var competitionLocations = [CustomPointAnnotation]()
    
    private var locationManager = CLLocationManager()
    
    var body: some View {
        Map(coordinateRegion: $region,
            showsUserLocation: true, // This line is important
            annotationItems: competitionLocations) { location in
                MapAnnotation(coordinate: location.coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                        .imageScale(.large)
                }
            }
        .edgesIgnoringSafeArea(.top) // for better display
        .onAppear {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()

            if let location = locationManager.location {
                region.center = location.coordinate
            }

            let db = Firestore.firestore()
            db.collection("competitions").getDocuments { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    competitionLocations = querySnapshot?.documents.compactMap { document in
                        let data = document.data()
                        if let lat = data["latitude"] as? Double, let lon = data["longitude"] as? Double {
                            return CustomPointAnnotation(coordinate: .init(latitude: lat, longitude: lon))
                        }
                        return nil
                    } ?? []
                }
            }
        }
    }
}

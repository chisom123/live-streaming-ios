import SwiftUI
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastLocation: CLLocation?

    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        self.locationManager.delegate = self
        self.locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.authorizationStatus = status
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }

    // Add this method to request location access
    func requestLocationAccess() {
        locationManager.requestWhenInUseAuthorization()
    }
}



struct LocationCheckView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var navigateToNextView = false
    @State private var navigateToDeniedView = false
    
    var body: some View {
        VStack {
            HStack {
                
                Spacer()
                
                Button("Skip") {
                    
                }
                .font(.system(size: 16, weight: .bold, design: .default))
                .foregroundColor(.black)
                .padding()
            }
            
            Spacer()
            
            Text("£")
                .font(.system(size: 30, weight: .bold, design: .default))
                .foregroundColor(Color(hex: "#DAA520"))
                .padding()
                .background(Circle()
                    .stroke(Color(hex: "#DAA520"), lineWidth: 3)
                )
                .padding(.horizontal)
            
            Text("Enter the Prize Pot")
                .font(.system(size: 22, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(Color(hex: "#DAA520"))
                .padding(.bottom, 30)
                .padding(.top, 20)
                .padding(.horizontal)
            
            Text("I'm baby jianbing sartorial mlkshk vexillologist. Lomo small batch jean shorts, readymade migas squid paleo next level tumeric chicharrones fashion axe man bun.")
                .font(.system(size: 17, weight: .semibold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.bottom, 10)
            
            
            Button(action: {
                checkLocationAndNavigate()
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .background(Color(hex: "#1199FF"))
                    .foregroundColor(Color(hex: "#fff"))
                    .cornerRadius(200)
            }
            .padding(.top, 30)
            
            Text("Available only in the UK")
                .font(.system(size: 15, weight: .semibold, design: .default))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .foregroundColor(.black)
                .padding(.top, 30)
            
            Spacer()
            
        }
        .fullScreenCover(isPresented: $navigateToNextView) {
            SelectMoneyView() // Replace this with the actual view you want to present
        }
        .padding()
    }
    
    private func checkLocationAndNavigate() {
        self.locationManager.requestLocationAccess()

        let status = CLLocationManager.authorizationStatus()
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if let location = locationManager.lastLocation {
                let coordinate = location.coordinate
                if isLocationWithinUK(coordinate: coordinate) {
                    navigateToNextView = true
                } else {
                    navigateToDeniedView = true
                }
            }
        default:
            // SORT OUT ALL THE EDGE CASES
            // Handle other authorization statuses (denied, restricted, notDetermined)
            navigateToDeniedView = true
        }
    }

    private func isLocationWithinUK(coordinate: CLLocationCoordinate2D) -> Bool {
        // Adjusted latitude and longitude range for a more accurate UK location check
        let latitudeRange = 49.9...60.85
        let longitudeRange = -8.0...1.78
        return latitudeRange.contains(coordinate.latitude) && longitudeRange.contains(coordinate.longitude)
    }
}

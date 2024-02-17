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
                // Request location access
                self.locationManager.requestLocationAccess()
                
                navigateToNextView = true

//                // Check if we already have a location; if not, the check will happen in the delegate methods
//                if CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways {
//                    if let location = locationManager.lastLocation {
//                        let coordinate = location.coordinate
//                        // Simplified check for the UK location
//                        if (49.9...60.9).contains(coordinate.latitude) && (-10.5...1.8).contains(coordinate.longitude) {
//                            navigateToNextView = true
//                        } else {
//                            navigateToDeniedView = true
//                        }
//                    }
//                }
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
            PayView() // Replace this with the actual view you want to present
        }
        .padding()
    }
}

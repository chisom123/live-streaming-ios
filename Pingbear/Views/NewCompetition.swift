//
//  NewCompetition.swift
//  Pingbear
//
//  Created by Ezi Agu on 02/08/1402 AP.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import CoreLocation
import UIKit

struct NewCompetition: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var competitionDescription: String = ""
    
    @State private var isCameraPresented = false
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image("Close")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .padding(.leading, 20)
                            .padding(.top, 20)
                    }
                    
                    Spacer() // This spacer will ensure the two buttons are at opposite ends.
                }
                
                Spacer()
                
                Text("New Competition")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.black)
                    .padding(.bottom, 40)
                    .padding(.horizontal)

                TextField("Describe Competition", text: $competitionDescription)
                    .keyboardType(.default)
                    .padding()
                    .background(Color(hex: "#F5F5F5"))
                    .foregroundColor(Color(hex: "#000"))
                    .cornerRadius(5)
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .padding(.horizontal)
        
                Button(action: {
                    newcomp()
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .background(Color(hex: "#1199FF"))
                        .foregroundColor(Color(hex: "#fff"))
                        .cornerRadius(200)
                }
                .padding(.top, 20)
                .padding(.horizontal)
                

                Spacer()
                
            }

        }
        .fullScreenCover(isPresented: $isCameraPresented, content: {
            CameraView()
        })
    }
    func newcomp() {
        // Location Manager for getting the current location
        let locationManager = CLLocationManager()
        
        // Ensure the user's location is available
        guard let userLocation = locationManager.location else {
            // Handle the case if unable to fetch the location
            print("Unable to get user location")
            return
        }

        // Firestore reference
        let db = Firestore.firestore()
        
        // Data to save
        let competitionData: [String: Any] = [
            "description": competitionDescription,
            "latitude": userLocation.coordinate.latitude,
            "longitude": userLocation.coordinate.longitude,
            "timestamp": Timestamp() // Current time
        ]
        
        self.isCameraPresented = true
        // Add a new document with the competition data
//        db.collection("competitions").addDocument(data: competitionData) { err in
//            if let err = err {
//                print("Error adding document: \(err)")
//            } else {
//                print("Document added")
//                // You can dismiss the current view or do something else
//                self.isCameraPresented = true
//            }
//        }
    }

}

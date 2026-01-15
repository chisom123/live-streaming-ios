import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct RealNameEntryView: View {
    let phoneNumber: String
    @State private var fullName: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var navigateToUsernameEntry = false

    var body: some View {
        VStack {
            
            Spacer()
            
            VStack {
                Text("What's your name?")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                    .padding(.bottom, 25)
                    .onAppear {
                        Analytics.shared.trackScreen(name: "real_name_entry")
                    }
                
                // Single Name TextField
                TextField("Enter your name", text: $fullName)
                    .padding()
                    .frame(height: 60)
                    .background(
                        Color(hex: "#3B4374")
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    )
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .autocapitalization(.words)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(Color(hex: "#FF0000"))
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .padding(.top, 20)
                        .padding(.horizontal)
                        .onAppear {
                            Analytics.shared.track(
                                event: "name_entry_error",
                                properties: ["error": error]
                            )
                        }
                }
                
                if isLoading {
                    ProgressView()
                        .padding(.vertical, 20)
                        .tint(.white)
                } else {
                    Button(action: {
                        self.validateAndContinue()
                    }) {
                        Text("Continue")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .background(Color(hex: "#4169E1"))
                            .foregroundColor(Color(hex: "#fff"))
                            .cornerRadius(200)
                    }
                    .padding(.vertical, 20)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(hex: "#1A2245"))
            .cornerRadius(10)
            .padding(.horizontal, 20)
            
            NavigationLink(destination: NameEntryView(phoneNumber: phoneNumber, fullName: fullName), isActive: $navigateToUsernameEntry) {
                EmptyView()
            }.isDetailLink(false)
            
            Spacer()
        }
        .background(Color(hex: "#10183C"))
        .navigationBarHidden(true)
    }
    
    func validateAndContinue() {
        errorMessage = nil
        
        // Remove leading whitespace only, keep trailing whitespace
        let trimmedName = String(fullName.drop(while: { $0.isWhitespace }))
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter your name"
            Analytics.shared.track(
                event: "name_validation_failed",
                properties: ["error": "Name empty"]
            )
            return
        }
        
        guard trimmedName.count >= 2 else {
            errorMessage = "Name must be at least 2 characters"
            Analytics.shared.track(
                event: "name_validation_failed",
                properties: ["error": "Name too short"]
            )
            return
        }
        
        fullName = trimmedName
        
        Analytics.shared.track(
            event: "name_entered",
            properties: ["name_length": trimmedName.count]
        )
        
        navigateToUsernameEntry = true
    }
}

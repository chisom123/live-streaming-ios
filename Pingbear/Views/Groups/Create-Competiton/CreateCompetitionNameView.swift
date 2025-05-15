import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// New Step 1: Name First Approach
struct CreateCompetitionNameView: View {
    @State private var competitionName: String = ""
    @State private var navigateToShareStep = false
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isThemeNameFocused: Bool
    
    let characterLimit = 50
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("New Competition")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 27, height: 27)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                // Progress indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: "#FF4081"))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                .padding(.bottom, 30)
                
                // Main content
                VStack(spacing: 0) {
                    
                    Text("Name Your Competition")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.bottom, 12)
                    
                    Text("Choose a memorable name that your friends will recognize")
                        .font(.system(size: 16, weight: .medium))
                        .lineSpacing(4)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                    
                    // Input field
                    VStack(alignment: .trailing, spacing: 8) {
                        TextField("", text: $competitionName)
                            .placeholder(when: competitionName.isEmpty) {
                                Text("Enter competition name")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                            .background(Color(hex: "#1A2245"))
                            .cornerRadius(15)
                            .focused($isThemeNameFocused)
                            .onChange(of: competitionName) { newValue in
                                if newValue.count > characterLimit {
                                    competitionName = String(newValue.prefix(characterLimit))
                                }
                            }
                        
                        Text("\(competitionName.count)/\(characterLimit)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.trailing, 5)
                            .padding(.top, 5)
                    }
                    .padding(.horizontal, 30)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isThemeNameFocused = true
                        }
                        Analytics.shared.trackScreen(name: "create_competition_name")
                    }
                    
                    Spacer()
                    
                    // Continue button
                    Button(action: {
                        navigateToShareStep = true
                    }) {
                        Text("Continue")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .background(!competitionName.isEmpty ? Color(hex: "#FF4081") : Color(hex: "#D3D3D3").opacity(0.2))
                            .foregroundColor(!competitionName.isEmpty  ? Color(hex: "#FFF") : Color(hex: "#D3D3D3").opacity(0.2))
                            .cornerRadius(200)
                    }
                    .disabled(competitionName.isEmpty)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
            }
            .accentColor(.white)
        }
        .background(Color(hex: "#10183C"))
        .fullScreenCover(isPresented: $navigateToShareStep) {
            CreateCompetitionShareView(competitionName: competitionName)
        }
    }
}

// Extension for placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

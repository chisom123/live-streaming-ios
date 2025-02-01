import SwiftUI
import FirebaseFirestore
import PostHog

struct EditCompetitionView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var competitionName: String
    @State private var errorMessage: String? = nil
    
    let competition: Competition
    
    init(competition: Competition) {
        self.competition = competition
        _competitionName = State(initialValue: competition.description)
    }
    
    func isValidName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && trimmedName.count <= 50
    }
    
    func updateCompetitionName() {
        guard isValidName(competitionName) else {
            errorMessage = "Please enter a name (maximum 50 characters)"
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("competitions").document(competition.id).updateData([
            "description": competitionName.trimmingCharacters(in: .whitespacesAndNewlines)
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = "Failed to update: \(error.localizedDescription)"
                } else {
                    self.competition.description = self.competitionName
                    PostHogSDK.shared.capture("Competition Name Updated", properties: [
                        "competitionId": competition.id,
                        "newName": competitionName
                    ])
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    var body: some View {
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
                
                Text("Edit Name")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: updateCompetitionName) {
                    Text("Save")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "#FFF"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(hex: "#1A2245"))
            
            VStack(alignment: .leading, spacing: 20) {
                TextField("Competition name", text: $competitionName)
                    .padding()
                    .frame(height: 60)
                    .background(Color(hex: "#3B4374"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .font(.system(size: 16, weight: .bold, design: .default))
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(Color(hex: "#FF0000"))
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            
            Spacer()
        }
        .background(Color(hex: "#10183C"))
        .accentColor(.white)
        .ignoresSafeArea()
        .onAppear {
            PostHogSDK.shared.capture("Edit Name View Opened")
        }
    }
}

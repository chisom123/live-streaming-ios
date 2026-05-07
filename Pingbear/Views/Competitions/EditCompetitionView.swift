import SwiftUI
import FirebaseFirestore

struct EditCompetitionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var competitionName: String
    @State private var errorMessage: String? = nil
    @FocusState private var isNameFocused: Bool
    let competition: Competition

    init(competition: Competition) {
        self.competition = competition
        let displayName = competition.description == "Competition" ? "" : competition.description
        _competitionName = State(initialValue: displayName)
    }

    func isValidName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && trimmedName.count <= 50
    }

    func updateCompetitionName() {
        guard isValidName(competitionName) else { errorMessage = "Please enter a name (maximum 50 characters)"; return }
        let db = Firestore.firestore()
        db.collection("competitions").document(competition.id).updateData([
            "description": competitionName.trimmingCharacters(in: .whitespacesAndNewlines)
        ]) { error in
            DispatchQueue.main.async {
                if let error = error { errorMessage = "Failed to update: \(error.localizedDescription)" }
                else {
                    self.competition.description = self.competitionName
                    Analytics.shared.trackCompetition(action: "edit", competitionId: competition.id, properties: ["new_name": competitionName])
                    dismiss()
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left").resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 27, height: 27).foregroundColor(AppTheme.primaryText)
                }
                Spacer()
                Text("Edit Name").font(.system(size: 18, weight: .bold, design: .default)).foregroundColor(AppTheme.primaryText)
                Spacer()
                Button(action: updateCompetitionName) {
                    Text("Save").font(.system(size: 17, weight: .bold)).foregroundColor(AppTheme.primaryText)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 20)
            .background(AppTheme.cardBackground)

            VStack(alignment: .leading, spacing: 20) {
                TextField("Competition name", text: $competitionName)
                    .padding().frame(height: 60)
                    .background(AppTheme.cardHighlight)
                    .foregroundColor(AppTheme.primaryText).cornerRadius(10)
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .focused($isNameFocused)
                if let error = errorMessage {
                    Text(error).foregroundColor(.red)
                        .font(.system(size: 16, weight: .bold, design: .default)).multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, 20).padding(.top, 30)
            Spacer()
        }
        .background(AppTheme.pageBackground)
        .tint(AppTheme.accent)
        .ignoresSafeArea()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isNameFocused = true }
            Analytics.shared.trackScreen(name: "edit_competition")
        }
    }
}

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainTabView: View {
    @State private var selectedTab: Int
    @State private var isRecruit: Bool = false
    @State private var isLoadingRecruitStatus: Bool = true
    
    init(isNewUser: Bool = false) {
        _selectedTab = State(initialValue: isNewUser ? 1 : 0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Content
                if isLoadingRecruitStatus {
                    // Show loading state while fetching recruit status
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(hex: "#10183C"))
                } else {
                    TabView(selection: $selectedTab) {
                        MyCompsView()
                            .tag(0)
                        
                        GlobalLeaderboardView(selectedTab: $selectedTab)
                            .tag(1)
                        
                        if isRecruit {
                            RecruitsView()
                                .tag(2)
                        }
                        
                        SettingsView()
                            .tag(isRecruit ? 3 : 2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    // Custom Tab Bar
                    CustomTabBar(selectedTab: $selectedTab, isRecruit: isRecruit)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom - 15, 0))
                        .background(Color(hex: "#10183C"))
                }
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .background(Color(hex: "#10183C"))
        .onAppear {
            fetchRecruitStatus()
        }
    }
    
    private func fetchRecruitStatus() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoadingRecruitStatus = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching recruit status: \(error)")
                
                Analytics.shared.trackError(
                    message: "Failed to fetch recruit status",
                    properties: [
                        "error": error.localizedDescription
                    ]
                )
                
                isLoadingRecruitStatus = false
                return
            }
            
            if let data = snapshot?.data(),
               let recruitStatus = data["recruit"] as? Bool {
                isRecruit = recruitStatus
                
                Analytics.shared.track(
                    event: "recruit_status_loaded",
                    properties: [
                        "is_recruit": recruitStatus
                    ]
                )
            } else {
                // Default to false if field doesn't exist
                isRecruit = false
            }
            
            isLoadingRecruitStatus = false
        }
    }
}

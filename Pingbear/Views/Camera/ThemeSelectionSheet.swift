import SwiftUI
import FirebaseAuth

// MARK: - Empty State View
struct ThemeEmptyStateView: View {
    var action: () -> Void
    
    var body: some View {
        VStack {
            Text("No Themes Yet")
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(.white)
                .padding(.top, 20)
                .padding(.bottom, 20)
            
            VStack() {
                Button(action: action) {
                    HStack {
                        Text("New Theme")
                            .font(.system(size: 17, weight: .bold, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "#4169E1"))
                    .foregroundColor(.white)
                    .cornerRadius(200)
                }
            }
            .frame(width: 280)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(hex: "#1A2245"))
        .cornerRadius(10)
        .padding(.horizontal, 20)
    }
}

// MARK: - Updated Theme Selection Sheet
struct ThemeSelectionSheet: View {
    @ObservedObject var viewModel: ThemesViewModel
    let competitionId: String
    @Binding var selectedTheme: Theme?
    @State private var newThemeName: String = ""
    @State private var isAddingNewTheme: Bool = false
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color(hex: "#10183C").edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header with plus button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Pick a Theme")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Plus button to add a new theme
                    Button(action: {
                        isAddingNewTheme = true
                    }) {
                        Image(systemName: "plus")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 23, height: 23)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color(hex: "#1A2245"))
                
                // Only show search bar when there are themes
                if !viewModel.themes.isEmpty {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.7))
                        
                        TextField("Search Themes", text: $searchText)
                            .foregroundColor(.white)
                            .accentColor(.white)
                            .font(.system(size: 16, weight: .bold))
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding()
                    .background(Color(hex: "#3B4374"))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.vertical)
                }
                
                // Content area
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    Spacer()
                } else if viewModel.themes.isEmpty {
                    // Empty state
                    Spacer()
                    ThemeEmptyStateView {
                        isAddingNewTheme = true
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredThemes.enumerated()), id: \.element.id) { index, theme in
                                VStack(spacing: 0) {
                                    Button(action: {
                                        selectedTheme = theme
                                        dismiss()
                                    }) {
                                        HStack {
                                            Text(theme.name)
                                                .foregroundColor(.white)
                                                .font(.system(size: 16, weight: .bold))
                                                .padding(.leading, 10)
                                                .truncationMode(.tail)
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            if selectedTheme?.id == theme.id {
                                                Image(systemName: "checkmark")
                                                    .bold()
                                                    .foregroundColor(Color(hex: "#FFF"))
                                                    .padding(.trailing, 10)
                                            }
                                        }
                                        .padding(.vertical, 22)
                                        .padding(.horizontal, 15)
                                        .background(selectedTheme?.id == theme.id ? Color(hex: "#2A3255") : Color.clear)
                                    }
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                }
                            }
                            
                            // Add New Theme button at bottom of list
                            Button(action: {
                                isAddingNewTheme = true
                            }) {
                                HStack {
                                    Spacer()
                                    
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(Color(hex: "#FFF"))
                                        .font(.system(size: 20))
                                    
                                    Text("Add New Theme")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16, weight: .bold))
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 22)
                            }
                        }
                        .background(Color(hex: "#1A2245"))
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingNewTheme) {
            AddThemeSheet(
                competitionId: competitionId,
                viewModel: viewModel,
                isPresented: $isAddingNewTheme
            )
        }
        .onAppear {
            viewModel.loadThemes(for: competitionId)
            Analytics.shared.trackScreen(name: "theme_selection")
        }
        .accentColor(.white)
        .edgesIgnoringSafeArea(.top)
    }
    
    // Filter themes based on search text
    private var filteredThemes: [Theme] {
        if searchText.isEmpty {
            return viewModel.themes
        } else {
            return viewModel.themes.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
}

// MARK: - Add Theme Sheet
struct AddThemeSheet: View {
    let competitionId: String
    @ObservedObject var viewModel: ThemesViewModel
    @Binding var isPresented: Bool
    @State private var themeName: String = ""
    @State private var errorMessage: String? = nil
    @State private var isSaving: Bool = false
    @State private var selectedSuggestionIndex: Int? = nil
    @FocusState private var isThemeNameFocused: Bool
    
    // Dynamic theme suggestions based on user's current day
    private var themeSuggestions: [String] {
        let currentDayName = getCurrentDayName()
        return [
            "Outfit of the Day",
            "WTF",
            "\(currentDayName) Mood",
            "Caught in 4K",
            "Another Late Night",
            "Mirror Check"
        ]
    }
    
    // Get current day name in user's local timezone
    private func getCurrentDayName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Full day name (e.g., "Tuesday", "Wednesday")
        formatter.timeZone = TimeZone.current // Uses user's local timezone
        return formatter.string(from: Date())
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Add New Theme")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        isSaving = true
                        createTheme()
                    }) {
                        Text("Save")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(themeName.isEmpty ? Color.white.opacity(0.5) : Color.white)
                    }
                    .disabled(themeName.isEmpty || isSaving)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color(hex: "#1A2245"))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Theme name input field
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Theme Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.8))
                                .padding(.bottom, 5)
                            
                            TextField("Enter theme name", text: $themeName)
                                .padding()
                                .frame(height: 60)
                                .background(Color(hex: "#3B4374"))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .font(.system(size: 16, weight: .bold))
                                .focused($isThemeNameFocused)
                                .onChange(of: themeName) { _ in
                                    // Clear selection when user types manually
                                    selectedSuggestionIndex = nil
                                }
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(Color(hex: "#FF0000"))
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .multilineTextAlignment(.leading)
                                .padding(.bottom, 5)
                        }
                        
                        // Only show suggestions if the text field is empty
                        if themeName.isEmpty {
                            // Suggestions title
                            Text("Suggested Themes")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.8))
                                .padding(.top, 10)
                            
                            // Theme suggestions grid
                            suggestionsGrid
                                .padding(.top, 5)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
                .background(Color(hex: "#10183C"))
            }
            .background(Color(hex: "#10183C"))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isThemeNameFocused = true
                }
                Analytics.shared.trackScreen(name: "add_new_theme")
            }
        }
        .accentColor(.white)
    }
    
    // Theme suggestions grid layout
    private var suggestionsGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<(themeSuggestions.count + 1) / 2, id: \.self) { rowIndex in
                HStack(spacing: 0) {
                    let leftIndex = rowIndex * 2
                    let rightIndex = leftIndex + 1
                    
                    suggestionCell(index: leftIndex, theme: themeSuggestions[leftIndex])
                    
                    if rightIndex < themeSuggestions.count {
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .frame(width: 1)
                        
                        suggestionCell(index: rightIndex, theme: themeSuggestions[rightIndex])
                    }
                }
                
                if rowIndex < (themeSuggestions.count + 1) / 2 - 1 {
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .frame(height: 1)
                }
            }
        }
        .background(Color(hex: "#1A2245"))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // Individual suggestion cell
    private func suggestionCell(index: Int, theme: String) -> some View {
        let isSelected = selectedSuggestionIndex == index
        
        return Button(action: {
            self.selectedSuggestionIndex = index
            self.themeName = theme
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Text(theme)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.white)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 65)
                .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func createTheme() {
        // Clear previous error message
        errorMessage = nil
        
        // Basic validation
        guard !themeName.isEmpty else {
            errorMessage = "Please enter a theme name"
            isSaving = false
            return
        }
        
        // Validate theme name length
        if themeName.count > 25 {
            errorMessage = "Theme name must be 25 characters or less"
            isSaving = false
            return
        }
        
        // Check if theme already exists
        if viewModel.themes.contains(where: { $0.name.lowercased() == themeName.lowercased() }) {
            errorMessage = "This theme already exists"
            isSaving = false
            return
        }
        
        // Create theme
        viewModel.addTheme(name: themeName, competitionId: competitionId) { success in
            DispatchQueue.main.async {
                isSaving = false
                if success {
                    isPresented = false
                } else {
                    errorMessage = "Failed to create theme. Please try again."
                }
            }
        }
    }
}

// MARK: - Theme Badge
struct ThemeBadgeClickable: View {
    let themeName: String
    let themeId: String?
    let competitionId: String
    
    @State private var isShowingThemeView = false
    
    // Add convenience initializer for backward compatibility
    init(themeName: String, themeId: String?, competitionId: String) {
        self.themeName = themeName
        self.themeId = themeId
        self.competitionId = competitionId
    }
    
    var body: some View {
        Button(action: {
            if themeId != nil {
                isShowingThemeView = true
                Analytics.shared.track(
                    event: "theme_badge_clicked",
                    properties: [
                        "theme_name": themeName
                    ]
                )
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundColor(.white)
                
                Text(themeName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .truncationMode(.tail)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "#4169E1"))
            .cornerRadius(20)
        }
        .fullScreenCover(isPresented: $isShowingThemeView) {
            if let themeId = themeId {
                ThemePhotosView(
                    themeName: themeName,
                    themeId: themeId,
                    competitionId: competitionId
                )
            }
        }
    }
}

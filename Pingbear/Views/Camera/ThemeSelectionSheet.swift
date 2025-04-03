import SwiftUI
import FirebaseAuth

// MARK: - Theme Selection Sheet
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
                    
                    Text("Select a Theme")
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
                
                // Themes list
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
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
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(Color(hex: "#FF4081"))
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
                            
                            // Original Add New Theme button (kept)
                            Button(action: {
                                isAddingNewTheme = true
                            }) {
                                HStack {
                                    Spacer()
                                    
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(Color(hex: "#FF4081"))
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
                        .padding(.top, 10)
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
    @FocusState private var isThemeNameFocused: Bool
    
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
                    
                    Button(action: createTheme) {
                        Text("Save")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(themeName.isEmpty ? Color.white.opacity(0.5) : Color.white)
                    }
                    .disabled(themeName.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color(hex: "#1A2245"))
                
                VStack(alignment: .leading, spacing: 20) {
                    
                    TextField("Theme Name", text: $themeName)
                        .padding()
                        .frame(height: 60)
                        .background(Color(hex: "#3B4374"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.system(size: 16, weight: .bold))
                        .focused($isThemeNameFocused)
                    
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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isThemeNameFocused = true
                }
            }
        }
        .accentColor(.white)
    }
    
    private func createTheme() {
        // Clear previous error message
        errorMessage = nil
        
        // Basic validation
        guard !themeName.isEmpty else {
            errorMessage = "Please enter a theme name"
            return
        }
        
        // Validate theme name length
        if themeName.count > 25 {
            errorMessage = "Theme name must be 25 characters or less"
            return
        }
        
        // Check if theme already exists
        if viewModel.themes.contains(where: { $0.name.lowercased() == themeName.lowercased() }) {
            errorMessage = "This theme already exists"
            return
        }
        
        // Create theme
        viewModel.addTheme(name: themeName, competitionId: competitionId) { success in
            DispatchQueue.main.async {
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
struct ThemeBadge: View {
    let themeName: String
    
    var body: some View {
        Text(themeName)
            .font(.system(size: 16, weight: .bold))
            .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
            .background(Color(hex: "#FF8C00"))
            .foregroundColor(.white)
            .truncationMode(.tail)
            .lineLimit(1)
            .cornerRadius(15)
    }
}

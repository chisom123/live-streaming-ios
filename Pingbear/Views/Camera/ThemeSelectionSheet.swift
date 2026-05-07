import SwiftUI
import FirebaseAuth

// MARK: - Empty State View
struct ThemeEmptyStateView: View {
    var action: () -> Void

    var body: some View {
        VStack {
            Text("No Themes Yet")
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(AppTheme.primaryText)
                .padding(.top, 20)
                .padding(.bottom, 20)

            VStack {
                Button(action: action) {
                    HStack {
                        Text("New Theme")
                            .font(.system(size: 17, weight: .bold, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(200)
                }
            }
            .frame(width: 280)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppTheme.cardBackground)
        .cornerRadius(10)
        .padding(.horizontal, 20)
    }
}

// MARK: - Theme Selection Before Camera Sheet
struct ThemeSelectionBeforeCameraSheet: View {
    @ObservedObject var viewModel: ThemesViewModel
    let competitionId: String
    @Binding var selectedTheme: Theme?
    var onContinue: () -> Void
    @State private var isAddingNewTheme: Bool = false
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.pageBackground.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(AppTheme.iconColor)
                    }

                    Spacer()

                    Text("Pick a Theme")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundColor(AppTheme.primaryText)

                    Spacer()

                    Button(action: { isAddingNewTheme = true }) {
                        Image(systemName: "plus")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 23, height: 23)
                            .foregroundColor(AppTheme.iconColor)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(AppTheme.cardBackground)

                if !viewModel.themes.isEmpty {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.secondaryText)

                        TextField("Search Themes", text: $searchText)
                            .foregroundColor(AppTheme.primaryText)
                            .tint(AppTheme.accent)
                            .font(.system(size: 16, weight: .bold))

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                        }
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.vertical)
                }

                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(AppTheme.primaryText).scaleEffect(1.2)
                    Spacer()
                } else if viewModel.themes.isEmpty {
                    Spacer()
                    ThemeEmptyStateView { isAddingNewTheme = true }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filteredThemes, id: \.id) { theme in
                                VStack(spacing: 0) {
                                    Button(action: {
                                        selectedTheme = theme
                                        Analytics.shared.track(
                                            event: "theme_selected_before_camera",
                                            properties: ["theme_name": theme.name, "theme_id": theme.id, "competition_id": competitionId]
                                        )
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                        onContinue()
                                    }) {
                                        HStack {
                                            Text(theme.name)
                                                .foregroundColor(AppTheme.primaryText)
                                                .font(.system(size: 16, weight: .bold))
                                                .padding(.leading, 10)
                                                .truncationMode(.tail)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.vertical, 22)
                                        .padding(.horizontal, 15)
                                    }
                                    Divider().background(AppTheme.divider)
                                }
                            }

                            Button(action: { isAddingNewTheme = true }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(AppTheme.accent)
                                        .font(.system(size: 20))
                                    Text("Add New Theme")
                                        .foregroundColor(AppTheme.accent)
                                        .font(.system(size: 16, weight: .bold))
                                    Spacer()
                                }
                                .padding(.vertical, 22)
                            }
                        }
                        .background(AppTheme.cardBackground)
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingNewTheme) {
            AddThemeSheet(competitionId: competitionId, viewModel: viewModel, isPresented: $isAddingNewTheme)
        }
        .onAppear {
            viewModel.loadThemes(for: competitionId)
            Analytics.shared.trackScreen(name: "theme_selection_before_camera")
        }
    }

    private var filteredThemes: [Theme] {
        searchText.isEmpty ? viewModel.themes : viewModel.themes.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
}

// MARK: - Theme Selection Sheet
struct ThemeSelectionSheet: View {
    @ObservedObject var viewModel: ThemesViewModel
    let competitionId: String
    @Binding var selectedTheme: Theme?
    @State private var isAddingNewTheme: Bool = false
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.pageBackground.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(AppTheme.iconColor)
                    }

                    Spacer()

                    Text("Pick a Theme")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundColor(AppTheme.primaryText)

                    Spacer()

                    Button(action: { isAddingNewTheme = true }) {
                        Image(systemName: "plus")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 23, height: 23)
                            .foregroundColor(AppTheme.iconColor)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(AppTheme.cardBackground)

                if !viewModel.themes.isEmpty {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.secondaryText)

                        TextField("Search Themes", text: $searchText)
                            .foregroundColor(AppTheme.primaryText)
                            .tint(AppTheme.accent)
                            .font(.system(size: 16, weight: .bold))

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                        }
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.vertical)
                }

                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(AppTheme.primaryText).scaleEffect(1.2)
                    Spacer()
                } else if viewModel.themes.isEmpty {
                    Spacer()
                    ThemeEmptyStateView { isAddingNewTheme = true }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredThemes.enumerated()), id: \.element.id) { index, theme in
                                VStack(spacing: 0) {
                                    Button(action: { selectedTheme = theme; dismiss() }) {
                                        HStack {
                                            Text(theme.name)
                                                .foregroundColor(AppTheme.primaryText)
                                                .font(.system(size: 16, weight: .bold))
                                                .padding(.leading, 10)
                                                .truncationMode(.tail)
                                                .lineLimit(1)

                                            Spacer()

                                            if selectedTheme?.id == theme.id {
                                                Image(systemName: "checkmark")
                                                    .bold()
                                                    .foregroundColor(AppTheme.accent)
                                                    .padding(.trailing, 10)
                                            }
                                        }
                                        .padding(.vertical, 22)
                                        .padding(.horizontal, 15)
                                        .background(selectedTheme?.id == theme.id ? AppTheme.cardHighlight : Color.clear)
                                    }
                                    Divider().background(AppTheme.divider)
                                }
                            }

                            Button(action: { isAddingNewTheme = true }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(AppTheme.accent)
                                        .font(.system(size: 20))
                                    Text("Add New Theme")
                                        .foregroundColor(AppTheme.accent)
                                        .font(.system(size: 16, weight: .bold))
                                    Spacer()
                                }
                                .padding(.vertical, 22)
                            }
                        }
                        .background(AppTheme.cardBackground)
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingNewTheme) {
            AddThemeSheet(competitionId: competitionId, viewModel: viewModel, isPresented: $isAddingNewTheme)
        }
        .onAppear {
            viewModel.loadThemes(for: competitionId)
            Analytics.shared.trackScreen(name: "theme_selection")
        }
        .tint(AppTheme.accent)
        .edgesIgnoringSafeArea(.top)
    }

    private var filteredThemes: [Theme] {
        searchText.isEmpty ? viewModel.themes : viewModel.themes.filter { $0.name.lowercased().contains(searchText.lowercased()) }
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

    private var themeSuggestions: [String] {
        ["Outfit of the Day", "Mood", "Selfie", "Food", "Out n about", "WTF", "Caught in 4K"]
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(AppTheme.iconColor)
                    }

                    Spacer()

                    Text("Add New Theme")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundColor(AppTheme.primaryText)

                    Spacer()

                    Button(action: { isSaving = true; createTheme() }) {
                        Text("Save")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(themeName.isEmpty ? AppTheme.disabledText : AppTheme.accent)
                    }
                    .disabled(themeName.isEmpty || isSaving)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(AppTheme.cardBackground)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Theme Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.secondaryText)
                                .padding(.bottom, 5)

                            TextField("Enter theme name", text: $themeName)
                                .padding()
                                .frame(height: 60)
                                .background(AppTheme.cardBackground)
                                .foregroundColor(AppTheme.primaryText)
                                .cornerRadius(10)
                                .font(.system(size: 16, weight: .bold))
                                .tint(AppTheme.accent)
                                .focused($isThemeNameFocused)
                                .onChange(of: themeName) { _ in selectedSuggestionIndex = nil }
                        }

                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .multilineTextAlignment(.leading)
                                .padding(.bottom, 5)
                        }

                        if themeName.isEmpty && !isThemeNameFocused {
                            Text("Suggested Themes")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.secondaryText)
                                .padding(.top, 10)

                            suggestionsGrid.padding(.top, 5)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
                .background(AppTheme.pageBackground)
            }
        }
        .tint(AppTheme.accent)
        .onAppear { Analytics.shared.trackScreen(name: "add_new_theme") }
    }

    private var suggestionsGrid: some View {
        VStack(spacing: 0) {
            ForEach(Array(themeSuggestions.enumerated()), id: \.offset) { index, theme in
                Button(action: {
                    self.selectedSuggestionIndex = index
                    self.themeName = theme
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    HStack {
                        Text(theme)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.primaryText)
                        Spacer()
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.accent)
                            .font(.system(size: 19))
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 22)
                    .background(Color.clear)
                    .contentShape(Rectangle())
                }

                if index < themeSuggestions.count - 1 {
                    Divider().background(AppTheme.divider)
                }
            }
        }
        .background(AppTheme.cardBackground)
        .cornerRadius(10)
    }

    private func createTheme() {
        errorMessage = nil
        
        guard !themeName.isEmpty else {
            errorMessage = "Please enter a theme name"
            isSaving = false
            return
        }
        
        if themeName.count > 25 {
            errorMessage = "Theme name must be 25 characters or less"
            isSaving = false
            return
        }
        
        if viewModel.themes.contains(where: { $0.name.lowercased() == themeName.lowercased() }) {
            errorMessage = "This theme already exists"
            isSaving = false
            return
        }
        
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

    init(themeName: String, themeId: String?, competitionId: String) {
        self.themeName = themeName
        self.themeId = themeId
        self.competitionId = competitionId
    }

    var body: some View {
        Button(action: {
            if themeId != nil {
                isShowingThemeView = true
                Analytics.shared.track(event: "theme_badge_clicked", properties: ["theme_name": themeName])
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
            .background(AppTheme.accent)
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

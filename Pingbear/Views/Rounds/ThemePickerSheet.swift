import SwiftUI

// ─────────────────────────────────────────────────────────────
// MARK: - Empty State View
// ─────────────────────────────────────────────────────────────

struct ThemeEmptyStateView: View {
    var action: () -> Void

    var body: some View {
        VStack {
            Text("No Themes Yet")
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
                .padding(.top, 20)
                .padding(.bottom, 20)

            VStack {
                Button(action: action) {
                    Text("New Theme")
                        .font(.system(size: 17, weight: .bold))
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

// ─────────────────────────────────────────────────────────────
// MARK: - Theme Picker Sheet
// ─────────────────────────────────────────────────────────────

struct ThemePickerSheet: View {
    let competition: Competition
    let onSelected: (String?, String) -> Void

    @StateObject private var themesViewModel = ThemesViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingNewTheme = false
    @State private var searchText: String = ""

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────
                HStack {
                    Button(action: {
                        Analytics.shared.trackTap(
                            elementId: "theme_picker_dismiss",
                            screenName: "theme_picker"
                        )
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(AppTheme.iconColor)
                    }

                    Spacer()

                    Text("Pick a Theme")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)

                    Spacer()

                    Button(action: {
                        Analytics.shared.trackTap(
                            elementId: "theme_picker_add_new",
                            screenName: "theme_picker"
                        )
                        isAddingNewTheme = true
                    }) {
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

                // ── Search bar (only when themes exist) ───────────
                if !themesViewModel.themes.isEmpty {
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

                // ── Content ───────────────────────────────────────
                if themesViewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.primaryText)
                        .scaleEffect(1.2)
                    Spacer()
                } else if themesViewModel.themes.isEmpty {
                    Spacer()
                    ThemeEmptyStateView {
                        Analytics.shared.trackTap(
                            elementId: "theme_empty_state_add_new",
                            screenName: "theme_picker"
                        )
                        isAddingNewTheme = true
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filteredThemes, id: \.id) { theme in
                                Button(action: {
                                    Analytics.shared.trackTap(
                                        elementId: "theme_select",
                                        screenName: "theme_picker",
                                        properties: [
                                            AnalyticsProperty.competitionId: competition.id,
                                            "theme_name": theme.name
                                        ]
                                    )
                                    onSelected(theme.id, theme.name)
                                }) {
                                    HStack {
                                        Text(theme.name)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(AppTheme.primaryText)
                                            .padding(.leading, 10)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        Spacer()
                                    }
                                    .padding(.vertical, 22)
                                    .padding(.horizontal, 15)
                                }
                                Divider()
                                    .background(AppTheme.divider)
                            }

                            // ── Add new theme row ─────────────────
                            Button(action: {
                                Analytics.shared.trackTap(
                                    elementId: "theme_picker_add_new_row",
                                    screenName: "theme_picker"
                                )
                                isAddingNewTheme = true
                            }) {
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
            AddThemeSheet(
                competitionId: competition.id,
                viewModel: themesViewModel,
                isPresented: $isAddingNewTheme
            )
        }
        .onAppear {
            Analytics.shared.trackScreen(
                name: "theme_picker",
                properties: [AnalyticsProperty.competitionId: competition.id]
            )
            themesViewModel.loadThemes(for: competition.id)
        }
    }

    private var filteredThemes: [Theme] {
        searchText.isEmpty
            ? themesViewModel.themes
            : themesViewModel.themes.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Add Theme Sheet
// ─────────────────────────────────────────────────────────────

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
                    Button(action: {
                        Analytics.shared.trackTap(
                            elementId: "add_theme_dismiss",
                            screenName: "add_new_theme"
                        )
                        isPresented = false
                    }) {
                        Image(systemName: "arrow.left")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 27, height: 27)
                            .foregroundColor(AppTheme.iconColor)
                    }

                    Spacer()

                    Text("Add New Theme")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)

                    Spacer()

                    Button(action: {
                        isSaving = true
                        createTheme()
                    }) {
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
                                .font(.system(size: 16, weight: .bold))
                                .multilineTextAlignment(.leading)
                                .padding(.bottom, 5)
                        }

                        if themeName.isEmpty && !isThemeNameFocused {
                            Text("Suggested Themes")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.secondaryText)
                                .padding(.top, 10)

                            suggestionsGrid
                                .padding(.top, 5)
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
        .onAppear {
            Analytics.shared.trackScreen(
                name: "add_new_theme",
                properties: [AnalyticsProperty.competitionId: competitionId]
            )
        }
    }

    private var suggestionsGrid: some View {
        VStack(spacing: 0) {
            ForEach(Array(themeSuggestions.enumerated()), id: \.offset) { index, theme in
                Button(action: {
                    Analytics.shared.trackTap(
                        elementId: "theme_suggestion_select",
                        screenName: "add_new_theme",
                        properties: ["theme_name": theme]
                    )
                    selectedSuggestionIndex = index
                    themeName = theme
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    HStack {
                        Text(theme)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.primaryText)
                        Spacer()
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.accent)
                            .font(.system(size: 19, weight: .bold))
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
                    Analytics.shared.track(
                        event: "theme_created",
                        properties: [
                            AnalyticsProperty.competitionId: competitionId,
                            "theme_name": themeName
                        ]
                    )
                    isPresented = false
                } else {
                    Analytics.shared.trackError(
                        message: "Failed to create theme",
                        properties: [
                            AnalyticsProperty.competitionId: competitionId,
                            "theme_name": themeName
                        ]
                    )
                    errorMessage = "Failed to create theme. Please try again."
                }
            }
        }
    }
}

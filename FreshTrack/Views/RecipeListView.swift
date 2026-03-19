//
//  RecipeListView.swift
//  FreshTrack
//
//  Created by Claude on 1/28/26.
//

import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Grocery> { grocery in
        grocery.consumedDate == nil
    }, sort: \Grocery.expirationDate) private var groceries: [Grocery]
    @Query(sort: \SavedRecipe.savedAt, order: .reverse) private var savedRecipes: [SavedRecipe]

    @Query private var interactions: [RecipeInteraction]
    @Query(filter: #Predicate<Grocery> { !$0.isConsumed }) private var activeGroceries: [Grocery]

    @StateObject private var recommendationService = RecipeRecommendationService.shared

    @State private var searchText = ""
    @State private var selectedDiet: String?
    @State private var showFilters = false
    @State private var searchMode: SearchMode = .saved
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRecommendation: RecipeRecommendation?

    // Ingredient selection
    @State private var selectedIngredients: Set<String> = []
    @State private var ingredientSelectorExpanded: Bool = true

    // Search results
    @State private var searchResults: [Recipe] = []
    @State private var ingredientResults: [RecipeByIngredient] = []
    @State private var totalResults = 0

    // Navigation
    @State private var selectedRecipeId: Int?

    enum SearchMode: String, CaseIterable {
        case saved = "Saved"
        case search = "Search"
        case byIngredients = "My Ingredients"
        case expiring = "Expiring"
    }

    private let dietOptions = [
        "vegetarian", "vegan", "glutenFree", "dairyFree", "ketogenic", "paleo"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search mode picker
                Picker("Mode", selection: $searchMode) {
                    ForEach(SearchMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: searchMode) { _, newMode in
                    if newMode == .byIngredients && selectedIngredients.isEmpty {
                        selectedIngredients = Set(availableIngredients)
                    }
                    performSearch()
                }

                // Content
                Group {
                    if searchMode == .saved {
                        savedRecipesView
                    } else if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if searchMode == .search {
                        searchResultsView
                    } else {
                        ingredientResultsView
                    }
                }
            }
            .navigationTitle("Recipes")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .searchable(text: $searchText, prompt: searchPrompt)
            .onSubmit(of: .search) {
                performSearch()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFilters.toggle()
                    } label: {
                        Image(systemName: selectedDiet != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                filterSheet
            }
            .navigationDestination(item: $selectedRecipeId) { recipeId in
                RecipeDetailView(recipeId: recipeId)
            }
            .onAppear {
                if searchMode != .saved && searchResults.isEmpty && ingredientResults.isEmpty {
                    performSearch()
                }
                refreshRecommendations()
            }
            .onChange(of: interactions.count) {
                refreshRecommendations()
            }
            .sheet(item: $selectedRecommendation) { rec in
                NavigationStack {
                    RecipeDetailView(recipeId: rec.id)
                }
            }
        }
    }

    // MARK: - Saved Recipe Row

    private struct SavedRecipeRow: View {
        let recipe: SavedRecipe

        var body: some View {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: recipe.image)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Rectangle()
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(.headline)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        if recipe.readyInMinutes != nil {
                            Label(recipe.cookingTimeText, systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let servings = recipe.servings {
                            Label("\(servings)", systemImage: "person.2")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !recipe.dietTags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(recipe.dietTags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.green.opacity(0.15), in: Capsule())
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Search Prompt

    private var searchPrompt: String {
        switch searchMode {
        case .saved:
            return "Filter saved recipes..."
        case .search:
            return "Search recipes..."
        case .byIngredients, .expiring:
            return "Filter results..."
        }
    }

    // MARK: - Saved Recipes View

    private var savedRecipesView: some View {
        Group {
            let filteredSaved = searchText.isEmpty
                ? savedRecipes
                : savedRecipes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }

            if filteredSaved.isEmpty {
                if savedRecipes.isEmpty {
                    ContentUnavailableView {
                        Label("No Saved Recipes", systemImage: "bookmark")
                    } description: {
                        Text("Tap the bookmark icon on any recipe to save it for later.")
                    } actions: {
                        Button("Search Recipes") {
                            searchMode = .search
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label("No Matches", systemImage: "magnifyingglass")
                    } description: {
                        Text("No saved recipes match '\(searchText)'")
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Recommendations at the top when not searching
                        if searchText.isEmpty && !recommendationService.recommendations.isEmpty {
                            recommendationsSection
                            Divider()
                                .padding(.vertical, 8)
                        }

                        // Saved recipes list
                        LazyVStack(spacing: 0) {
                            ForEach(filteredSaved) { saved in
                                SavedRecipeRow(recipe: saved)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedRecipeId = saved.recipeId
                                    }
                                    .padding(.horizontal)
                                if saved.recipeId != filteredSaved.last?.recipeId {
                                    Divider()
                                        .padding(.leading, 108)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func deleteSavedRecipes(at offsets: IndexSet) {
        let filteredSaved = searchText.isEmpty
            ? savedRecipes
            : savedRecipes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }

        for index in offsets {
            modelContext.delete(filteredSaved[index])
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Finding recipes...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                performSearch()
            }
        }
    }

    // MARK: - Search Results View

    private var searchResultsView: some View {
        Group {
            if searchResults.isEmpty {
                ContentUnavailableView {
                    Label("No Recipes Found", systemImage: "fork.knife")
                } description: {
                    Text("Try a different search term or adjust your filters.")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(searchResults) { recipe in
                            RecipeCard(recipe: recipe)
                                .onTapGesture {
                                    selectedRecipeId = recipe.id
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Ingredient Results View

    private var ingredientResultsView: some View {
        Group {
            if searchMode == .byIngredients && availableIngredients.isEmpty {
                ContentUnavailableView {
                    Label("No Ingredients", systemImage: "carrot")
                } description: {
                    Text("Add some groceries to your pantry first.")
                }
            } else if searchMode == .expiring && expiringIngredients.isEmpty {
                ContentUnavailableView {
                    Label("No Expiring Items", systemImage: "checkmark.circle")
                } description: {
                    Text("You don't have any items expiring soon. Great job!")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Ingredient selector (only on My Ingredients tab)
                        if searchMode == .byIngredients {
                            ingredientSelector
                        } else {
                            ingredientsSummary
                        }

                        if ingredientResults.isEmpty {
                            ContentUnavailableView {
                                Label("No Recipes Found", systemImage: "fork.knife")
                            } description: {
                                Text("No recipes found with the selected ingredients.")
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(ingredientResults) { recipe in
                                RecipeByIngredientCard(recipe: recipe)
                                    .onTapGesture {
                                        selectedRecipeId = recipe.id
                                    }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Ingredient Selector (My Ingredients tab)

    private var ingredientSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row with hide/show toggle
            HStack {
                Text("Select ingredients to search with:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        ingredientSelectorExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(ingredientSelectorExpanded ? "Hide" : "Show")
                            .font(.caption)
                        Image(systemName: ingredientSelectorExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tint)
                }
            }

            if ingredientSelectorExpanded {
                HStack {
                    Spacer()
                    Button {
                        if selectedIngredients.count == availableIngredients.count {
                            selectedIngredients = []
                        } else {
                            selectedIngredients = Set(availableIngredients)
                        }
                    } label: {
                        Text(selectedIngredients.count == availableIngredients.count ? "Deselect All" : "Select All")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }

                FlowLayout(spacing: 8) {
                    ForEach(availableIngredients.sorted(), id: \.self) { ingredient in
                        let isSelected = selectedIngredients.contains(ingredient)
                        Button {
                            if isSelected {
                                selectedIngredients.remove(ingredient)
                            } else {
                                selectedIngredients.insert(ingredient)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                }
                                Text(ingredient)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2), in: Capsule())
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                    }
                }
            }

            Button {
                performSearch()
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text(selectedIngredients.isEmpty
                         ? "Select ingredients to search"
                         : "Search with \(selectedIngredients.count) ingredient\(selectedIngredients.count == 1 ? "" : "s")")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedIngredients.isEmpty ? Color.gray.opacity(0.2) : Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(selectedIngredients.isEmpty ? Color.secondary : Color.white)
            }
            .disabled(selectedIngredients.isEmpty)
            .padding(.top, 4)
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Ingredients Summary (Expiring tab)

    private var ingredientsSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Using expiring items:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(expiringIngredients.prefix(10), id: \.self) { ingredient in
                        Text(ingredient)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                    if expiringIngredients.count > 10 {
                        Text("+\(expiringIngredients.count - 10) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Filter Sheet

    private var filterSheet: some View {
        NavigationStack {
            List {
                Section("Diet") {
                    ForEach(dietOptions, id: \.self) { diet in
                        Button {
                            if selectedDiet == diet {
                                selectedDiet = nil
                            } else {
                                selectedDiet = diet
                            }
                        } label: {
                            HStack {
                                Text(diet.capitalized)
                                Spacer()
                                if selectedDiet == diet {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Section {
                    Button("Clear Filters", role: .destructive) {
                        selectedDiet = nil
                    }
                    .disabled(selectedDiet == nil)
                }
            }
            .navigationTitle("Filters")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showFilters = false
                        performSearch()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Recommendations

    private func refreshRecommendations() {
        let expiring = activeGroceries.filter {
            $0.expirationStatus == .critical || $0.expirationStatus == .warning
        }
        recommendationService.refresh(
            savedRecipes: savedRecipes,
            interactions: interactions,
            expiringGroceries: expiring
        )
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("Recommended for You")
                    .font(.headline)
                Spacer()
                Text(currentMealLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recommendationService.recommendations) { rec in
                        Button {
                            selectedRecommendation = rec
                        } label: {
                            RecommendationCard(
                                recommendation: rec,
                                onLike: {
                                    InteractionTrackingService.shared.log(
                                        recipeId: rec.id,
                                        recipeTitle: rec.title,
                                        type: .liked,
                                        context: modelContext
                                    )
                                },
                                onDislike: {
                                    InteractionTrackingService.shared.log(
                                        recipeId: rec.id,
                                        recipeTitle: rec.title,
                                        type: .disliked,
                                        context: modelContext
                                    )
                                }
                            )
                            .frame(width: 200)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    private var currentMealLabel: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return "Breakfast"
        case 11..<15: return "Lunch"
        case 15..<18: return "Snack"
        default:      return "Dinner"
        }
    }

    // MARK: - Computed Properties

    private var availableIngredients: [String] {
        groceries.map { $0.name }
    }

    private var expiringIngredients: [String] {
        let sevenDaysFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return groceries
            .filter { grocery in
                let expDate = grocery.expirationDate ?? grocery.predictedExpirationDate ?? Date.distantFuture
                return expDate <= sevenDaysFromNow
            }
            .map { $0.name }
    }

    // MARK: - Search

    private func performSearch() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                switch searchMode {
                case .saved:
                    // Saved recipes are loaded via @Query, no API call needed
                    await MainActor.run {
                        isLoading = false
                    }
                    return

                case .search:
                    let response = try await RecipeAPIService.shared.searchRecipes(
                        query: searchText.isEmpty ? nil : searchText,
                        diet: selectedDiet,
                        number: 20
                    )
                    await MainActor.run {
                        searchResults = response.results
                        totalResults = response.totalResults
                        ingredientResults = []
                    }

                case .byIngredients:
                    let ingredients = Array(selectedIngredients)
                    guard !ingredients.isEmpty else {
                        await MainActor.run {
                            ingredientResults = []
                            searchResults = []
                            isLoading = false
                        }
                        return
                    }
                    let response = try await RecipeAPIService.shared.searchByIngredients(
                        ingredients: ingredients,
                        number: 20
                    )
                    await MainActor.run {
                        ingredientResults = response.results
                        searchResults = []
                    }

                case .expiring:
                    let ingredients = expiringIngredients
                    guard !ingredients.isEmpty else {
                        await MainActor.run {
                            ingredientResults = []
                            searchResults = []
                            isLoading = false
                        }
                        return
                    }
                    let response = try await RecipeAPIService.shared.recipesForExpiringItems(
                        ingredients: ingredients,
                        number: 15
                    )
                    await MainActor.run {
                        ingredientResults = response.results
                        searchResults = []
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - FlowLayout

/// Wrapping horizontal layout for ingredient chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > width && rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Grocery.self, SavedRecipe.self, RecipeInteraction.self, configurations: config)

    return RecipeListView()
        .modelContainer(container)
}

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

    @State private var searchText = ""
    @State private var selectedDiet: String?
    @State private var showFilters = false
    @State private var searchMode: SearchMode = .saved
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                .onChange(of: searchMode) { _, _ in
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
                List {
                    ForEach(filteredSaved) { saved in
                        SavedRecipeRow(recipe: saved)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRecipeId = saved.recipeId
                            }
                    }
                    .onDelete(perform: deleteSavedRecipes)
                }
                .listStyle(.plain)
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
            if ingredientResults.isEmpty {
                if expiringIngredients.isEmpty && searchMode == .expiring {
                    ContentUnavailableView {
                        Label("No Expiring Items", systemImage: "checkmark.circle")
                    } description: {
                        Text("You don't have any items expiring soon. Great job!")
                    }
                } else if availableIngredients.isEmpty && searchMode == .byIngredients {
                    ContentUnavailableView {
                        Label("No Ingredients", systemImage: "carrot")
                    } description: {
                        Text("Add some groceries to your pantry first.")
                    }
                } else {
                    ContentUnavailableView {
                        Label("No Recipes Found", systemImage: "fork.knife")
                    } description: {
                        Text("No recipes found with your current ingredients.")
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Ingredients being used
                        ingredientsSummary

                        ForEach(ingredientResults) { recipe in
                            RecipeByIngredientCard(recipe: recipe)
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

    // MARK: - Ingredients Summary

    private var ingredientsSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(searchMode == .expiring ? "Using expiring items:" : "Using your ingredients:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let ingredients = searchMode == .expiring ? expiringIngredients : availableIngredients
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ingredients.prefix(10), id: \.self) { ingredient in
                        Text(ingredient)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.tint.opacity(0.1), in: Capsule())
                    }
                    if ingredients.count > 10 {
                        Text("+\(ingredients.count - 10) more")
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
                    let ingredients = availableIngredients
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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Grocery.self, SavedRecipe.self, configurations: config)

    return RecipeListView()
        .modelContainer(container)
}

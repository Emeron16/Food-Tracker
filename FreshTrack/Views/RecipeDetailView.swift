//
//  RecipeDetailView.swift
//  FreshTrack
//
//  Created by Claude on 1/28/26.
//

import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    let recipeId: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var savedRecipes: [SavedRecipe]

    @State private var recipe: RecipeDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTab = 0
    @State private var showingSaveConfirmation = false

    private var isSaved: Bool {
        savedRecipes.contains { $0.recipeId == recipeId }
    }

    private var savedRecipe: SavedRecipe? {
        savedRecipes.first { $0.recipeId == recipeId }
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let recipe = recipe {
                recipeContent(recipe)
            }
        }
        .navigationTitle(recipe?.title ?? "Recipe")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if recipe != nil {
                    Button {
                        toggleSave()
                    } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(isSaved ? .yellow : .primary)
                    }
                }
            }
        }
        .task {
            await loadRecipe()
        }
        .overlay(alignment: .bottom) {
            if showingSaveConfirmation {
                saveConfirmationBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingSaveConfirmation)
    }

    // MARK: - Save Confirmation Banner

    private var saveConfirmationBanner: some View {
        HStack {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark.slash")
            Text(isSaved ? "Recipe saved!" : "Recipe removed")
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.tint, in: Capsule())
        .padding(.bottom, 20)
    }

    // MARK: - Toggle Save

    private func toggleSave() {
        if let existing = savedRecipe {
            modelContext.delete(existing)
        } else if let recipe = recipe {
            let saved = SavedRecipe(from: recipe)
            modelContext.insert(saved)
        }

        showingSaveConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingSaveConfirmation = false
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading recipe...")
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
                Task { await loadRecipe() }
            }
        }
    }

    // MARK: - Recipe Content

    private func recipeContent(_ recipe: RecipeDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header Image
                headerImage(recipe)

                VStack(alignment: .leading, spacing: 20) {
                    // Title and Info
                    titleSection(recipe)

                    Divider()

                    // Quick Info
                    quickInfoSection(recipe)

                    // Diet Tags
                    if !recipe.dietTags.isEmpty {
                        dietTagsSection(recipe)
                    }

                    Divider()

                    // Tab Selector
                    Picker("Section", selection: $selectedTab) {
                        Text("Ingredients").tag(0)
                        Text("Instructions").tag(1)
                    }
                    .pickerStyle(.segmented)

                    // Content based on selected tab
                    if selectedTab == 0 {
                        ingredientsSection(recipe)
                    } else {
                        instructionsSection(recipe)
                    }

                    // Source attribution
                    if !recipe.sourceName.isEmpty {
                        sourceSection(recipe)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Header Image

    private func headerImage(_ recipe: RecipeDetail) -> some View {
        AsyncImage(url: URL(string: recipe.image)) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        ProgressView()
                    }
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            @unknown default:
                Rectangle()
                    .fill(.quaternary)
            }
        }
        .frame(height: 250)
        .clipped()
    }

    // MARK: - Title Section

    private func titleSection(_ recipe: RecipeDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recipe.title)
                    .font(.title2)
                    .fontWeight(.bold)

                if isSaved {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(.yellow)
                        .font(.subheadline)
                }
            }

            if !recipe.cleanSummary.isEmpty {
                Text(recipe.cleanSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    // MARK: - Quick Info Section

    private func quickInfoSection(_ recipe: RecipeDetail) -> some View {
        HStack(spacing: 24) {
            if recipe.readyInMinutes != nil {
                VStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundStyle(.tint)
                    Text(recipe.cookingTimeText)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Cook Time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let servings = recipe.servings {
                VStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.title3)
                        .foregroundStyle(.tint)
                    Text("\(servings)")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Servings")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let healthScore = recipe.healthScore {
                VStack(spacing: 4) {
                    Image(systemName: "heart")
                        .font(.title3)
                        .foregroundStyle(.pink)
                    Text("\(healthScore)")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Health Score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Diet Tags Section

    private func dietTagsSection(_ recipe: RecipeDetail) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(recipe.dietTags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.green.opacity(0.15), in: Capsule())
                        .foregroundStyle(.green)
                }

                ForEach(recipe.cuisines, id: \.self) { cuisine in
                    Text(cuisine)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Ingredients Section

    private func ingredientsSection(_ recipe: RecipeDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(recipe.ingredients) { ingredient in
                    HStack(spacing: 12) {
                        // Ingredient image
                        if let imageUrl = ingredient.image {
                            AsyncImage(url: URL(string: imageUrl)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                default:
                                    Image(systemName: "leaf")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 40, height: 40)
                            .background(.quaternary, in: Circle())
                        } else {
                            Image(systemName: "leaf")
                                .frame(width: 40, height: 40)
                                .background(.quaternary, in: Circle())
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(ingredient.name.capitalized)
                                .font(.subheadline)
                            Text(ingredient.formattedAmount)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)

                    if ingredient.id != recipe.ingredients.last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Instructions Section

    private func instructionsSection(_ recipe: RecipeDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.headline)

            if recipe.instructions.isEmpty {
                Text(recipe.instructionsText.isEmpty ? "No instructions available." : recipe.instructionsText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 16) {
                    ForEach(recipe.instructions) { step in
                        HStack(alignment: .top, spacing: 12) {
                            // Step number
                            Text("\(step.number)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.tint, in: Circle())

                            VStack(alignment: .leading, spacing: 8) {
                                Text(step.step)
                                    .font(.subheadline)

                                // Equipment/ingredients needed
                                if !step.equipment.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "wrench.and.screwdriver")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(step.equipment.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        if step.number != recipe.instructions.last?.number {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Source Section

    private func sourceSection(_ recipe: RecipeDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recipe from")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let url = URL(string: recipe.sourceUrl) {
                Link(destination: url) {
                    HStack {
                        Text(recipe.sourceName)
                            .font(.subheadline)
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
            } else {
                Text(recipe.sourceName)
                    .font(.subheadline)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Load Recipe

    private func loadRecipe() async {
        // Check if we have it saved locally first
        if let saved = savedRecipe {
            await MainActor.run {
                self.recipe = saved.toRecipeDetail()
                self.isLoading = false
            }
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let detail = try await RecipeAPIService.shared.getRecipeDetail(id: recipeId)
            await MainActor.run {
                self.recipe = detail
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Grocery.self, SavedRecipe.self, configurations: config)

    return NavigationStack {
        RecipeDetailView(recipeId: 716429)
    }
    .modelContainer(container)
}

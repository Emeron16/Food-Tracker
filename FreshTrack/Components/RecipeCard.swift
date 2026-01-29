//
//  RecipeCard.swift
//  FreshTrack
//
//  Created by Claude on 1/28/26.
//

import SwiftUI

/// A card displaying recipe summary information
struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
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
            .frame(height: 140)
            .clipped()

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

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

                // Diet tags
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
            .padding(12)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

/// A card for ingredient-based recipe search results
struct RecipeByIngredientCard: View {
    let recipe: RecipeByIngredient

    var body: some View {
        HStack(spacing: 12) {
            // Image
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
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    Rectangle()
                        .fill(.quaternary)
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(2)

                // Ingredient match info
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(recipe.usedIngredientCount) ingredients used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if recipe.missedIngredientCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.orange)
                        Text("\(recipe.missedIngredientCount) more needed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Match percentage
                HStack {
                    ProgressView(value: recipe.matchPercentage, total: 100)
                        .tint(.green)
                    Text("\(Int(recipe.matchPercentage))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Previews

#Preview("Recipe Card") {
    RecipeCard(recipe: Recipe(
        id: 1,
        title: "Creamy Garlic Pasta with Roasted Vegetables",
        image: "https://spoonacular.com/recipeImages/716429-312x231.jpg",
        readyInMinutes: 45,
        servings: 4,
        sourceUrl: "",
        diets: ["vegetarian"],
        dishTypes: ["main course"],
        vegetarian: true,
        vegan: false,
        glutenFree: false,
        dairyFree: false,
        healthScore: 75
    ))
    .frame(width: 200)
    .padding()
}

#Preview("Recipe By Ingredient Card") {
    RecipeByIngredientCard(recipe: RecipeByIngredient(
        id: 1,
        title: "Chicken Stir Fry with Vegetables",
        image: "https://spoonacular.com/recipeImages/716429-312x231.jpg",
        usedIngredientCount: 4,
        missedIngredientCount: 2,
        usedIngredients: [
            IngredientInfo(name: "chicken", image: nil),
            IngredientInfo(name: "broccoli", image: nil),
        ],
        missedIngredients: [
            IngredientInfo(name: "soy sauce", image: nil),
        ]
    ))
    .padding()
}

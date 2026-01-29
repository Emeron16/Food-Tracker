//
//  SavedRecipe.swift
//  FreshTrack
//
//  Created by Claude on 1/28/26.
//

import Foundation
import SwiftData

/// A recipe saved/favorited by the user for offline access.
@Model
final class SavedRecipe {
    // MARK: - Core Properties
    var recipeId: Int
    var title: String
    var image: String
    var readyInMinutes: Int?
    var servings: Int?
    var sourceUrl: String
    var sourceName: String

    // MARK: - Diet Info
    var vegetarian: Bool
    var vegan: Bool
    var glutenFree: Bool
    var dairyFree: Bool
    var healthScore: Int?

    // MARK: - Content
    var summary: String
    var ingredientsJSON: String  // JSON encoded [RecipeIngredient]
    var instructionsJSON: String // JSON encoded [RecipeInstruction]
    var instructionsText: String

    // MARK: - Metadata
    var savedAt: Date
    var lastViewedAt: Date?
    var timesCooked: Int

    // MARK: - Initializer

    init(from detail: RecipeDetail) {
        self.recipeId = detail.id
        self.title = detail.title
        self.image = detail.image
        self.readyInMinutes = detail.readyInMinutes
        self.servings = detail.servings
        self.sourceUrl = detail.sourceUrl
        self.sourceName = detail.sourceName
        self.vegetarian = detail.vegetarian
        self.vegan = detail.vegan
        self.glutenFree = detail.glutenFree
        self.dairyFree = detail.dairyFree
        self.healthScore = detail.healthScore
        self.summary = detail.summary
        self.instructionsText = detail.instructionsText
        self.savedAt = Date()
        self.lastViewedAt = nil
        self.timesCooked = 0

        // Encode ingredients and instructions as JSON
        let encoder = JSONEncoder()
        self.ingredientsJSON = (try? String(data: encoder.encode(detail.ingredients), encoding: .utf8)) ?? "[]"
        self.instructionsJSON = (try? String(data: encoder.encode(detail.instructions), encoding: .utf8)) ?? "[]"
    }

    // MARK: - Computed Properties

    var ingredients: [RecipeIngredient] {
        guard let data = ingredientsJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([RecipeIngredient].self, from: data)) ?? []
    }

    var instructions: [RecipeInstruction] {
        guard let data = instructionsJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([RecipeInstruction].self, from: data)) ?? []
    }

    var cookingTimeText: String {
        guard let minutes = readyInMinutes else { return "N/A" }
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hr"
            }
            return "\(hours) hr \(remainingMinutes) min"
        }
    }

    var dietTags: [String] {
        var tags: [String] = []
        if vegetarian { tags.append("Vegetarian") }
        if vegan { tags.append("Vegan") }
        if glutenFree { tags.append("Gluten-Free") }
        if dairyFree { tags.append("Dairy-Free") }
        return tags
    }

    var cleanSummary: String {
        summary
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    /// Convert back to RecipeDetail for display
    func toRecipeDetail() -> RecipeDetail {
        RecipeDetail(
            id: recipeId,
            title: title,
            image: image,
            readyInMinutes: readyInMinutes,
            servings: servings,
            sourceUrl: sourceUrl,
            sourceName: sourceName,
            summary: summary,
            diets: [],
            dishTypes: [],
            cuisines: [],
            vegetarian: vegetarian,
            vegan: vegan,
            glutenFree: glutenFree,
            dairyFree: dairyFree,
            healthScore: healthScore,
            ingredients: ingredients,
            instructions: instructions,
            instructionsText: instructionsText
        )
    }
}

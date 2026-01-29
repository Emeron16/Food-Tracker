//
//  Recipe.swift
//  FreshTrack
//
//  Created by Claude on 1/28/26.
//

import Foundation

// MARK: - Recipe Models

/// Recipe summary for list views
struct Recipe: Identifiable, Codable, Sendable {
    let id: Int
    let title: String
    let image: String
    let readyInMinutes: Int?
    let servings: Int?
    let sourceUrl: String
    let diets: [String]
    let dishTypes: [String]
    let vegetarian: Bool
    let vegan: Bool
    let glutenFree: Bool
    let dairyFree: Bool
    let healthScore: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, image, servings, diets, vegetarian, vegan
        case readyInMinutes = "ready_in_minutes"
        case sourceUrl = "source_url"
        case dishTypes = "dish_types"
        case glutenFree = "gluten_free"
        case dairyFree = "dairy_free"
        case healthScore = "health_score"
    }

    /// Formatted cooking time string
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

    /// Diet tags for display
    var dietTags: [String] {
        var tags: [String] = []
        if vegetarian { tags.append("Vegetarian") }
        if vegan { tags.append("Vegan") }
        if glutenFree { tags.append("Gluten-Free") }
        if dairyFree { tags.append("Dairy-Free") }
        return tags
    }
}

/// Recipe from ingredient-based search
struct RecipeByIngredient: Identifiable, Codable, Sendable {
    let id: Int
    let title: String
    let image: String
    let usedIngredientCount: Int
    let missedIngredientCount: Int
    let usedIngredients: [IngredientInfo]
    let missedIngredients: [IngredientInfo]

    enum CodingKeys: String, CodingKey {
        case id, title, image
        case usedIngredientCount = "used_ingredient_count"
        case missedIngredientCount = "missed_ingredient_count"
        case usedIngredients = "used_ingredients"
        case missedIngredients = "missed_ingredients"
    }

    /// Percentage of ingredients used from user's list
    var matchPercentage: Double {
        let total = usedIngredientCount + missedIngredientCount
        guard total > 0 else { return 0 }
        return Double(usedIngredientCount) / Double(total) * 100
    }
}

/// Simple ingredient info
struct IngredientInfo: Codable, Sendable, Identifiable {
    let name: String
    let image: String?

    var id: String { name }
}

/// Full recipe details
struct RecipeDetail: Identifiable, Codable, Sendable {
    let id: Int
    let title: String
    let image: String
    let readyInMinutes: Int?
    let servings: Int?
    let sourceUrl: String
    let sourceName: String
    let summary: String
    let diets: [String]
    let dishTypes: [String]
    let cuisines: [String]
    let vegetarian: Bool
    let vegan: Bool
    let glutenFree: Bool
    let dairyFree: Bool
    let healthScore: Int?
    let ingredients: [RecipeIngredient]
    let instructions: [RecipeInstruction]
    let instructionsText: String

    enum CodingKeys: String, CodingKey {
        case id, title, image, servings, summary, diets, cuisines
        case vegetarian, vegan, ingredients, instructions
        case readyInMinutes = "ready_in_minutes"
        case sourceUrl = "source_url"
        case sourceName = "source_name"
        case dishTypes = "dish_types"
        case glutenFree = "gluten_free"
        case dairyFree = "dairy_free"
        case healthScore = "health_score"
        case instructionsText = "instructions_text"
    }

    /// Formatted cooking time string
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

    /// Diet tags for display
    var dietTags: [String] {
        var tags: [String] = []
        if vegetarian { tags.append("Vegetarian") }
        if vegan { tags.append("Vegan") }
        if glutenFree { tags.append("Gluten-Free") }
        if dairyFree { tags.append("Dairy-Free") }
        return tags
    }

    /// Cleaned summary (remove HTML tags)
    var cleanSummary: String {
        summary
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}

/// Recipe ingredient with amounts
struct RecipeIngredient: Identifiable, Codable, Sendable {
    let id: Int?
    let name: String
    let original: String
    let amount: Double?
    let unit: String
    let image: String?

    var formattedAmount: String {
        guard let amount = amount else { return original }
        let formatted = amount.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", amount)
            : String(format: "%.1f", amount)
        return unit.isEmpty ? formatted : "\(formatted) \(unit)"
    }
}

/// Recipe instruction step
struct RecipeInstruction: Identifiable, Codable, Sendable {
    let number: Int
    let step: String
    let ingredients: [String]
    let equipment: [String]

    var id: Int { number }
}

// MARK: - API Response Types

struct RecipeSearchResponse: Codable, Sendable {
    let results: [Recipe]
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case results
        case totalResults = "total_results"
    }
}

struct RecipeByIngredientResponse: Codable, Sendable {
    let results: [RecipeByIngredient]
}

//
//  RecipeInteraction.swift
//  FreshTrack
//

import Foundation
import SwiftData

/// The type of interaction a user had with a recipe.
enum InteractionType: String, Codable {
    case viewed    // User opened the recipe detail
    case saved     // User bookmarked the recipe
    case unsaved   // User removed the bookmark
    case cooked    // User marked as cooked (future)
    case skipped   // User dismissed a recommendation
    case liked     // User thumbs-up'd a recommendation
    case disliked  // User thumbs-down'd a recommendation
}

/// Records a single user interaction with a recipe, used to personalize recommendations.
@Model
final class RecipeInteraction {
    var recipeId: Int
    var recipeTitle: String
    var recipeImage: String = ""  // Spoonacular image URL
    var recipeCategory: String    // primary cuisine/dish type tag if available
    var interactionTypeRaw: String
    var timestamp: Date

    /// Hour of day (0-23) when the interaction occurred — used for time-of-day scoring
    var hourOfDay: Int

    var interactionType: InteractionType {
        get { InteractionType(rawValue: interactionTypeRaw) ?? .viewed }
        set { interactionTypeRaw = newValue.rawValue }
    }

    /// Weight of this interaction for scoring (liked > saved > cooked > viewed > skipped > disliked)
    var weight: Double {
        switch interactionType {
        case .liked:     return 3.0
        case .saved:     return 2.0
        case .cooked:    return 2.5
        case .viewed:    return 1.0
        case .unsaved:   return -1.0
        case .skipped:   return -0.5
        case .disliked:  return -2.0
        }
    }

    init(recipeId: Int, recipeTitle: String, recipeImage: String = "", recipeCategory: String = "", type: InteractionType) {
        self.recipeId = recipeId
        self.recipeTitle = recipeTitle
        self.recipeImage = recipeImage
        self.recipeCategory = recipeCategory
        self.interactionTypeRaw = type.rawValue
        self.timestamp = Date()
        self.hourOfDay = Calendar.current.component(.hour, from: Date())
    }
}

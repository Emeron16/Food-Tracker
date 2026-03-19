//
//  InteractionTrackingService.swift
//  FreshTrack
//

import Foundation
import SwiftData

/// Logs recipe interactions to SwiftData for use by RecipeRecommendationService.
@MainActor
final class InteractionTrackingService {
    static let shared = InteractionTrackingService()

    private init() {}

    /// Log an interaction. Call this whenever the user views, saves, likes, or skips a recipe.
    func log(
        recipeId: Int,
        recipeTitle: String,
        recipeImage: String = "",
        recipeCategory: String = "",
        type: InteractionType,
        context: ModelContext
    ) {
        let interaction = RecipeInteraction(
            recipeId: recipeId,
            recipeTitle: recipeTitle,
            recipeImage: recipeImage,
            recipeCategory: recipeCategory,
            type: type
        )
        context.insert(interaction)

        // Keep history trimmed to last 500 interactions to avoid unbounded growth
        pruneOldInteractions(context: context)
    }

    private func pruneOldInteractions(context: ModelContext) {
        let descriptor = FetchDescriptor<RecipeInteraction>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let all = try? context.fetch(descriptor), all.count > 500 else { return }
        let toDelete = all.dropFirst(500)
        toDelete.forEach { context.delete($0) }
    }
}

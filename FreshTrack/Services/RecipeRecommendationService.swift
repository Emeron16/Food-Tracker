//
//  RecipeRecommendationService.swift
//  FreshTrack
//
//  On-device recommendation engine. No server required.
//  Candidates: recipes the user has VIEWED but NOT saved — surfaces new discoveries.
//  Scores using three signals:
//    1. Interaction history (liked/viewed count, penalises disliked/skipped)
//    2. Time-of-day affinity (what they engage with at similar hours)
//    3. Expiring pantry items (boost recipes that use items expiring soon)
//

import Foundation
import SwiftData
import Combine

// MARK: - Recommendation Result

struct RecipeRecommendation: Identifiable {
    let id: Int          // recipeId
    let title: String
    let image: String
    let readyInMinutes: Int?
    let score: Double    // 0.0 – 1.0 normalised
    let reason: String   // "Why recommended?" explanation
}

// MARK: - Service

final class RecipeRecommendationService: ObservableObject {
    @MainActor static let shared = RecipeRecommendationService()

    @MainActor @Published var recommendations: [RecipeRecommendation] = []
    @MainActor @Published var isLoading = false

    private init() {}

    // MARK: - Public API

    /// Compute personalised recommendations from interaction history.
    /// Candidates are recipes the user has viewed but NOT saved — avoids duplicating the saved list.
    @MainActor
    func refresh(
        savedRecipes: [SavedRecipe],
        interactions: [RecipeInteraction],
        expiringGroceries: [Grocery]
    ) {
        // Build candidate pool: viewed recipes that are not currently saved
        let savedIds = Set(savedRecipes.map { $0.recipeId })

        // Deduplicate by recipeId, keeping the most recent interaction metadata
        var seen = Set<Int>()
        let candidates: [RecipeInteraction] = interactions
            .filter { $0.interactionType == .viewed && !savedIds.contains($0.recipeId) }
            .sorted { $0.timestamp > $1.timestamp }
            .filter { seen.insert($0.recipeId).inserted }

        guard !candidates.isEmpty else {
            recommendations = []
            return
        }

        isLoading = true
        let currentHour = Calendar.current.component(.hour, from: Date())
        let expiringCategories = Set(expiringGroceries.map { $0.category.rawValue.lowercased() })

        var scored: [(candidate: RecipeInteraction, score: Double, reason: String)] = []

        for candidate in candidates {
            let (score, reason) = scoreCandidate(
                candidate,
                allInteractions: interactions,
                currentHour: currentHour,
                expiringCategories: expiringCategories
            )
            // Exclude anything the user explicitly disliked or skipped heavily
            let negativeWeight = interactions
                .filter { $0.recipeId == candidate.recipeId }
                .reduce(0.0) { $0 + ([$1.interactionType == .disliked ? $1.weight : 0].first ?? 0) }
            if negativeWeight < -1.5 { continue }

            scored.append((candidate, score, reason))
        }

        let top = scored
            .sorted { $0.score > $1.score }
            .prefix(10)

        let maxScore = top.first?.score ?? 1.0

        recommendations = top.map { item in
            RecipeRecommendation(
                id: item.candidate.recipeId,
                title: item.candidate.recipeTitle,
                image: "",   // image not stored in interactions — card handles missing gracefully
                readyInMinutes: nil,
                score: maxScore > 0 ? item.score / maxScore : 0,
                reason: item.reason
            )
        }

        isLoading = false
    }

    // MARK: - Scoring

    private func scoreCandidate(
        _ candidate: RecipeInteraction,
        allInteractions: [RecipeInteraction],
        currentHour: Int,
        expiringCategories: Set<String>
    ) -> (score: Double, reason: String) {
        var score: Double = 0
        var reasons: [String] = []

        let recipeInteractions = allInteractions.filter { $0.recipeId == candidate.recipeId }

        // --- Signal 1: Interaction history ---
        let viewCount = recipeInteractions.filter { $0.interactionType == .viewed }.count
        let likeCount = recipeInteractions.filter { $0.interactionType == .liked }.count

        if likeCount > 0 {
            score += Double(likeCount) * 3.0
            reasons.append("You liked this recipe")
        } else if viewCount > 1 {
            score += Double(viewCount) * 0.5
            reasons.append("You've viewed this \(viewCount) times")
        }

        // --- Signal 2: Time-of-day affinity ---
        let sameHourViews = recipeInteractions.filter { interaction in
            let hourDiff = abs(interaction.hourOfDay - currentHour)
            let wrappedDiff = min(hourDiff, 24 - hourDiff)
            return wrappedDiff <= 2 && interaction.interactionType == .viewed
        }.count

        if sameHourViews > 0 {
            score += Double(sameHourViews) * 1.5
            reasons.append("You browse recipes like this at \(mealLabel(for: currentHour))")
        }

        // --- Signal 3: Expiring pantry boost ---
        let titleLower = candidate.recipeTitle.lowercased()
        let categoryLower = candidate.recipeCategory.lowercased()
        let expiringMatch = expiringCategories.contains { category in
            titleLower.contains(category) || categoryLower.contains(category)
        }
        if expiringMatch {
            score += 1.5
            reasons.append("Uses items expiring soon")
        }

        // Recency boost — recently viewed recipes are more relevant
        let hoursSinceViewed = Date().timeIntervalSince(candidate.timestamp) / 3600
        if hoursSinceViewed < 48 {
            score += 0.5
        }

        let reason = reasons.first ?? "Based on your browsing history"
        return (max(score, 0.1), reason)
    }

    // MARK: - Helpers

    private func mealLabel(for hour: Int) -> String {
        switch hour {
        case 5..<11:  return "breakfast"
        case 11..<15: return "lunch"
        case 15..<18: return "snack"
        default:      return "dinner"
        }
    }

    // MARK: - Explanation

    /// Full explanation string for "Why recommended?" sheet
    @MainActor
    func fullExplanation(for recommendation: RecipeRecommendation, interactions: [RecipeInteraction]) -> String {
        let recipeInteractions = interactions.filter { $0.recipeId == recommendation.id }
        var lines: [String] = []

        let likeCount = recipeInteractions.filter { $0.interactionType == .liked }.count
        let viewCount = recipeInteractions.filter { $0.interactionType == .viewed }.count

        if likeCount > 0 { lines.append("You liked this recipe \(likeCount) time\(likeCount > 1 ? "s" : "")") }
        if viewCount > 0 { lines.append("You've viewed it \(viewCount) time\(viewCount > 1 ? "s" : "")") }
        lines.append("Not yet saved — tap the bookmark to keep it")

        let hour = Calendar.current.component(.hour, from: Date())
        lines.append("Suggested for \(mealLabel(for: hour)) based on your history")

        if recommendation.reason.contains("expiring") {
            lines.append("Helps use ingredients expiring soon")
        }

        return lines.joined(separator: "\n")
    }
}

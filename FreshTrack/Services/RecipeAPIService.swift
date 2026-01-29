//
//  RecipeAPIService.swift
//  FreshTrack
//
//  Created by Claude on 1/28/26.
//

import Foundation

/// Service for fetching recipes directly from Spoonacular API.
/// This allows the app to work standalone without the backend server.
actor RecipeAPIService {
    static let shared = RecipeAPIService()

    private let baseURL = URL(string: "https://api.spoonacular.com")!
    private let session: URLSession

    // IMPORTANT: Replace with your Spoonacular API key
    // Get one free at: https://spoonacular.com/food-api
    private let apiKey = "0c3a3e49e6f74f80b6b4a2e56924be1e"


    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Search Recipes

    /// Search for recipes with filters
    func searchRecipes(
        query: String? = nil,
        ingredients: [String]? = nil,
        diet: String? = nil,
        maxReadyTime: Int? = nil,
        number: Int = 10,
        offset: Int = 0
    ) async throws -> RecipeSearchResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("recipes/complexSearch"), resolvingAgainstBaseURL: false)!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "number", value: String(min(number, 100))),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "addRecipeInformation", value: "true"),
            URLQueryItem(name: "fillIngredients", value: "true"),
        ]

        if let query = query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "query", value: query))
        }
        if let ingredients = ingredients, !ingredients.isEmpty {
            queryItems.append(URLQueryItem(name: "includeIngredients", value: ingredients.joined(separator: ",")))
        }
        if let diet = diet, !diet.isEmpty {
            queryItems.append(URLQueryItem(name: "diet", value: diet))
        }
        if let maxReadyTime = maxReadyTime {
            queryItems.append(URLQueryItem(name: "maxReadyTime", value: String(maxReadyTime)))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw RecipeAPIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RecipeAPIError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 402 {
                throw RecipeAPIError.apiKeyInvalid
            }
            throw RecipeAPIError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let spoonacularResponse = try decoder.decode(SpoonacularSearchResponse.self, from: data)

        return RecipeSearchResponse(
            results: spoonacularResponse.results.map { $0.toRecipe() },
            totalResults: spoonacularResponse.totalResults
        )
    }

    // MARK: - Search by Ingredients

    /// Find recipes based on available ingredients
    func searchByIngredients(
        ingredients: [String],
        number: Int = 10,
        maximizeUsed: Bool = true
    ) async throws -> RecipeByIngredientResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("recipes/findByIngredients"), resolvingAgainstBaseURL: false)!

        components.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "ingredients", value: ingredients.joined(separator: ",")),
            URLQueryItem(name: "number", value: String(min(number, 100))),
            URLQueryItem(name: "ranking", value: maximizeUsed ? "1" : "2"),
            URLQueryItem(name: "ignorePantry", value: "true"),
        ]

        guard let url = components.url else {
            throw RecipeAPIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RecipeAPIError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 402 {
                throw RecipeAPIError.apiKeyInvalid
            }
            throw RecipeAPIError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let spoonacularResults = try decoder.decode([SpoonacularByIngredientResult].self, from: data)

        return RecipeByIngredientResponse(
            results: spoonacularResults.map { $0.toRecipeByIngredient() }
        )
    }

    // MARK: - Recipes for Expiring Items

    /// Get recipes that use expiring ingredients (same as searchByIngredients with maximize used)
    func recipesForExpiringItems(
        ingredients: [String],
        number: Int = 10
    ) async throws -> RecipeByIngredientResponse {
        return try await searchByIngredients(
            ingredients: ingredients,
            number: number,
            maximizeUsed: true
        )
    }

    // MARK: - Recipe Detail

    /// Get full recipe details
    func getRecipeDetail(id: Int) async throws -> RecipeDetail {
        var components = URLComponents(url: baseURL.appendingPathComponent("recipes/\(id)/information"), resolvingAgainstBaseURL: false)!

        components.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "includeNutrition", value: "false"),
        ]

        guard let url = components.url else {
            throw RecipeAPIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RecipeAPIError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw RecipeAPIError.notFound
            }
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 402 {
                throw RecipeAPIError.apiKeyInvalid
            }
            throw RecipeAPIError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let spoonacularDetail = try decoder.decode(SpoonacularRecipeDetail.self, from: data)

        return spoonacularDetail.toRecipeDetail()
    }
}

// MARK: - Spoonacular API Response Types

private struct SpoonacularSearchResponse: Decodable, Sendable {
    let results: [SpoonacularRecipeSummary]
    let totalResults: Int
}

private struct SpoonacularRecipeSummary: Decodable, Sendable {
    let id: Int
    let title: String
    let image: String?
    let readyInMinutes: Int?
    let servings: Int?
    let sourceUrl: String?
    let diets: [String]?
    let dishTypes: [String]?
    let vegetarian: Bool?
    let vegan: Bool?
    let glutenFree: Bool?
    let dairyFree: Bool?
    let healthScore: Int?

    func toRecipe() -> Recipe {
        Recipe(
            id: id,
            title: title,
            image: image ?? "",
            readyInMinutes: readyInMinutes,
            servings: servings,
            sourceUrl: sourceUrl ?? "",
            diets: diets ?? [],
            dishTypes: dishTypes ?? [],
            vegetarian: vegetarian ?? false,
            vegan: vegan ?? false,
            glutenFree: glutenFree ?? false,
            dairyFree: dairyFree ?? false,
            healthScore: healthScore
        )
    }
}

private struct SpoonacularByIngredientResult: Decodable, Sendable {
    let id: Int
    let title: String
    let image: String?
    let usedIngredientCount: Int
    let missedIngredientCount: Int
    let usedIngredients: [SpoonacularIngredientInfo]?
    let missedIngredients: [SpoonacularIngredientInfo]?

    func toRecipeByIngredient() -> RecipeByIngredient {
        RecipeByIngredient(
            id: id,
            title: title,
            image: image ?? "",
            usedIngredientCount: usedIngredientCount,
            missedIngredientCount: missedIngredientCount,
            usedIngredients: (usedIngredients ?? []).map { IngredientInfo(name: $0.name, image: $0.image) },
            missedIngredients: (missedIngredients ?? []).map { IngredientInfo(name: $0.name, image: $0.image) }
        )
    }
}

private struct SpoonacularIngredientInfo: Decodable, Sendable {
    let name: String
    let image: String?
}

private struct SpoonacularRecipeDetail: Decodable, Sendable {
    let id: Int
    let title: String
    let image: String?
    let readyInMinutes: Int?
    let servings: Int?
    let sourceUrl: String?
    let sourceName: String?
    let summary: String?
    let diets: [String]?
    let dishTypes: [String]?
    let cuisines: [String]?
    let vegetarian: Bool?
    let vegan: Bool?
    let glutenFree: Bool?
    let dairyFree: Bool?
    let healthScore: Int?
    let extendedIngredients: [SpoonacularExtendedIngredient]?
    let analyzedInstructions: [SpoonacularAnalyzedInstruction]?
    let instructions: String?

    func toRecipeDetail() -> RecipeDetail {
        let ingredients = (extendedIngredients ?? []).map { ing in
            RecipeIngredient(
                id: ing.id,
                name: ing.name ?? "",
                original: ing.original ?? "",
                amount: ing.amount,
                unit: ing.unit ?? "",
                image: ing.image.map { "https://spoonacular.com/cdn/ingredients_100x100/\($0)" }
            )
        }

        var instructions: [RecipeInstruction] = []
        if let analyzed = analyzedInstructions?.first {
            instructions = (analyzed.steps ?? []).map { step in
                RecipeInstruction(
                    number: step.number,
                    step: step.step ?? "",
                    ingredients: (step.ingredients ?? []).map { $0.name ?? "" },
                    equipment: (step.equipment ?? []).map { $0.name ?? "" }
                )
            }
        }

        return RecipeDetail(
            id: id,
            title: title,
            image: image ?? "",
            readyInMinutes: readyInMinutes,
            servings: servings,
            sourceUrl: sourceUrl ?? "",
            sourceName: sourceName ?? "",
            summary: summary ?? "",
            diets: diets ?? [],
            dishTypes: dishTypes ?? [],
            cuisines: cuisines ?? [],
            vegetarian: vegetarian ?? false,
            vegan: vegan ?? false,
            glutenFree: glutenFree ?? false,
            dairyFree: dairyFree ?? false,
            healthScore: healthScore,
            ingredients: ingredients,
            instructions: instructions,
            instructionsText: self.instructions ?? ""
        )
    }
}

private struct SpoonacularExtendedIngredient: Decodable, Sendable {
    let id: Int?
    let name: String?
    let original: String?
    let amount: Double?
    let unit: String?
    let image: String?
}

private struct SpoonacularAnalyzedInstruction: Decodable, Sendable {
    let steps: [SpoonacularStep]?
}

private struct SpoonacularStep: Decodable, Sendable {
    let number: Int
    let step: String?
    let ingredients: [SpoonacularStepItem]?
    let equipment: [SpoonacularStepItem]?
}

private struct SpoonacularStepItem: Decodable, Sendable {
    let name: String?
}

// MARK: - Errors

enum RecipeAPIError: LocalizedError {
    case invalidURL
    case networkError
    case serverError(Int)
    case notFound
    case decodingError
    case apiKeyInvalid

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL."
        case .networkError:
            return "Unable to connect. Check your connection and try again."
        case .serverError(let code):
            return "Server error (code \(code)). Please try again."
        case .notFound:
            return "Recipe not found."
        case .decodingError:
            return "Unable to process server response."
        case .apiKeyInvalid:
            return "Invalid API key. Please configure your Spoonacular API key."
        }
    }
}

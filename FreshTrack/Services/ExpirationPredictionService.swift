//
//  ExpirationPredictionService.swift
//  FreshTrack
//
//  Created by Claude on 1/28/26.
//

import Foundation
import CoreML
import Combine

// MARK: - Prediction Result

/// Result of an expiration prediction containing days, confidence, and calculated date.
struct ExpirationPrediction: Sendable {
    let days: Int
    let confidenceScore: Double
    let expirationDate: Date

    init(days: Int, confidenceScore: Double, from purchaseDate: Date = Date()) {
        self.days = days
        self.confidenceScore = confidenceScore
        self.expirationDate = Calendar.current.date(byAdding: .day, value: days, to: purchaseDate) ?? purchaseDate
    }
}

// MARK: - Prediction Errors

/// Errors that can occur during prediction.
enum PredictionError: LocalizedError {
    case modelNotLoaded
    case predictionFailed(String)
    case invalidInput

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "ML model could not be loaded"
        case .predictionFailed(let reason):
            return "Prediction failed: \(reason)"
        case .invalidInput:
            return "Invalid input for prediction"
        }
    }
}

// MARK: - Expiration Prediction Service

/// Service for on-device expiration date prediction using Core ML.
/// Falls back to category-based defaults when ML model is unavailable.
@MainActor
class ExpirationPredictionService: ObservableObject {
    static let shared = ExpirationPredictionService()

    @Published private(set) var isModelLoaded = false

    private var model: MLModel?

    /// Confidence lookup based on category-storage combination reliability.
    /// Higher confidence for combinations with more consistent shelf life data.
    private let confidenceMap: [String: Double] = [
        // Dairy
        "Dairy-Refrigerator": 0.92,
        "Dairy-Freezer": 0.88,
        "Dairy-Pantry": 0.50,
        "Dairy-Counter": 0.50,

        // Meat
        "Meat-Refrigerator": 0.90,
        "Meat-Freezer": 0.88,
        "Meat-Pantry": 0.40,
        "Meat-Counter": 0.40,

        // Seafood
        "Seafood-Refrigerator": 0.88,
        "Seafood-Freezer": 0.85,
        "Seafood-Pantry": 0.40,
        "Seafood-Counter": 0.40,

        // Produce - higher variance due to variety
        "Produce-Refrigerator": 0.75,
        "Produce-Freezer": 0.85,
        "Produce-Pantry": 0.72,
        "Produce-Counter": 0.70,

        // Bakery
        "Bakery-Counter": 0.82,
        "Bakery-Refrigerator": 0.80,
        "Bakery-Freezer": 0.88,
        "Bakery-Pantry": 0.78,

        // Frozen - very consistent
        "Frozen-Freezer": 0.95,
        "Frozen-Refrigerator": 0.70,
        "Frozen-Pantry": 0.50,
        "Frozen-Counter": 0.50,

        // Pantry items - long shelf life, consistent
        "Pantry-Pantry": 0.92,
        "Pantry-Refrigerator": 0.88,
        "Pantry-Freezer": 0.90,
        "Pantry-Counter": 0.85,

        // Beverages
        "Beverages-Refrigerator": 0.85,
        "Beverages-Pantry": 0.88,
        "Beverages-Freezer": 0.85,
        "Beverages-Counter": 0.75,

        // Condiments - long shelf life, consistent
        "Condiments-Refrigerator": 0.92,
        "Condiments-Pantry": 0.90,
        "Condiments-Freezer": 0.88,
        "Condiments-Counter": 0.75,

        // Snacks
        "Snacks-Pantry": 0.88,
        "Snacks-Refrigerator": 0.82,
        "Snacks-Freezer": 0.85,
        "Snacks-Counter": 0.80,

        // Other - lower confidence due to uncertainty
        "Other-Refrigerator": 0.70,
        "Other-Freezer": 0.75,
        "Other-Pantry": 0.68,
        "Other-Counter": 0.65
    ]

    private init() {
        loadModel()
    }

    // MARK: - Model Loading

    /// Attempt to load the Core ML model from the app bundle.
    private func loadModel() {
        // Try to load the compiled model
        // The model will be named "ExpirationPredictor" when added to the project
        guard let modelURL = Bundle.main.url(forResource: "ExpirationPredictor", withExtension: "mlmodelc") else {
            print("ExpirationPredictor.mlmodelc not found in bundle - using fallback predictions")
            isModelLoaded = false
            return
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndGPU
            model = try MLModel(contentsOf: modelURL, configuration: config)
            isModelLoaded = true
            print("ExpirationPredictor model loaded successfully")
        } catch {
            print("Failed to load ExpirationPredictor model: \(error)")
            isModelLoaded = false
        }
    }

    // MARK: - Prediction

    /// Predict expiration date for a food item based on category and storage location.
    /// - Parameters:
    ///   - category: The food category
    ///   - storageLocation: Where the item will be stored
    ///   - purchaseDate: When the item was purchased (default: today)
    /// - Returns: ExpirationPrediction with days, confidence, and calculated date
    func predict(
        category: FoodCategory,
        storageLocation: StorageLocation,
        purchaseDate: Date = Date()
    ) -> ExpirationPrediction {
        // If model is loaded, use ML prediction
        if let model = model {
            do {
                let prediction = try mlPredict(
                    model: model,
                    category: category,
                    storageLocation: storageLocation
                )
                let confidence = calculateConfidence(category: category, storage: storageLocation)

                return ExpirationPrediction(
                    days: prediction,
                    confidenceScore: confidence,
                    from: purchaseDate
                )
            } catch {
                print("ML prediction failed, using fallback: \(error)")
            }
        }

        // Fallback to rule-based prediction
        return fallbackPrediction(
            category: category,
            storageLocation: storageLocation,
            purchaseDate: purchaseDate
        )
    }

    /// Perform ML model inference.
    private func mlPredict(
        model: MLModel,
        category: FoodCategory,
        storageLocation: StorageLocation
    ) throws -> Int {
        // Create feature provider with input values
        let inputFeatures: [String: MLFeatureValue] = [
            "category": MLFeatureValue(string: category.rawValue),
            "storageLocation": MLFeatureValue(string: storageLocation.rawValue)
        ]

        let provider = try MLDictionaryFeatureProvider(dictionary: inputFeatures)
        let prediction = try model.prediction(from: provider)

        // Get the predicted days from output
        guard let expirationDays = prediction.featureValue(for: "expirationDays")?.doubleValue else {
            throw PredictionError.predictionFailed("Missing expirationDays in output")
        }

        return max(1, Int(round(expirationDays)))
    }

    /// Calculate confidence score based on category-storage combination.
    private func calculateConfidence(category: FoodCategory, storage: StorageLocation) -> Double {
        let key = "\(category.rawValue)-\(storage.rawValue)"
        return confidenceMap[key] ?? 0.70
    }

    // MARK: - Fallback Prediction

    /// Rule-based fallback prediction when ML model is unavailable.
    /// Uses category defaults adjusted for storage location.
    private func fallbackPrediction(
        category: FoodCategory,
        storageLocation: StorageLocation,
        purchaseDate: Date
    ) -> ExpirationPrediction {
        var days = category.defaultExpirationDays

        // Adjust based on storage location
        switch storageLocation {
        case .freezer:
            // Freezer significantly extends shelf life for most items
            switch category {
            case .dairy:
                days = 120
            case .meat:
                days = 180
            case .seafood:
                days = 120
            case .produce:
                days = 300
            case .bakery:
                days = 120
            case .frozen:
                days = 270
            case .pantry:
                days = 365
            case .beverages:
                days = 180
            case .condiments:
                days = 365
            case .snacks:
                days = 180
            case .other:
                days = 120
            }

        case .counter:
            // Counter storage reduces shelf life for perishables
            switch category {
            case .dairy, .meat, .seafood:
                days = 1  // Perishables shouldn't be on counter
            case .produce:
                days = min(days, 5)
            case .bakery:
                days = min(days, 5)
            case .frozen:
                days = 1  // Thawed items spoil quickly
            case .pantry, .condiments, .snacks:
                days = min(days, 60)
            case .beverages:
                days = min(days, 14)
            case .other:
                days = min(days, 7)
            }

        case .pantry:
            // Pantry storage - perishables shouldn't be here
            switch category {
            case .dairy, .meat, .seafood:
                days = 1
            case .frozen:
                days = 1
            case .produce:
                days = min(days, 14)  // Some produce like onions, potatoes
            case .bakery:
                days = min(days, 7)
            case .beverages:
                days = 180
            case .pantry, .condiments, .snacks:
                break  // Use default
            case .other:
                days = min(days, 30)
            }

        case .refrigerator:
            // Refrigerator is the default assumption for most categories
            break
        }

        // Fallback confidence is lower than ML confidence
        let confidence = calculateConfidence(category: category, storage: storageLocation) * 0.85

        return ExpirationPrediction(
            days: max(1, days),
            confidenceScore: confidence,
            from: purchaseDate
        )
    }
}

#!/usr/bin/env swift
//
//  TrainExpirationModel.swift
//  FreshTrack
//
//  Run this script in a Swift Playground or via terminal:
//  swift TrainExpirationModel.swift
//
//  Requirements:
//  - macOS 14.0+ with Xcode 15+ installed
//  - Create ML framework available
//
//  Output:
//  - ExpirationPredictor.mlmodel in the same directory
//

import Foundation
import CreateML

// MARK: - Training Data

let trainingDataPath = "./ExpirationTrainingData.json"

print("Loading training data from: \(trainingDataPath)")

do {
    // Load training data
    let trainingDataURL = URL(fileURLWithPath: trainingDataPath)
    let trainingData = try MLDataTable(contentsOf: trainingDataURL)

    print("Loaded \(trainingData.rows.count) training samples")
    print("Columns: \(trainingData.columnNames)")

    // Split into training and validation sets (80/20)
    let (trainData, testData) = trainingData.randomSplit(by: 0.8, seed: 42)

    print("Training samples: \(trainData.rows.count)")
    print("Test samples: \(testData.rows.count)")

    // Configure and train the regressor
    print("\nTraining Boosted Tree Regressor...")

    let regressor = try MLBoostedTreeRegressor(
        trainingData: trainData,
        targetColumn: "expirationDays",
        featureColumns: ["category", "storageLocation"],
        parameters: MLBoostedTreeRegressor.ModelParameters(
            maxDepth: 6,
            maxIterations: 100,
            minLossReduction: 0.0,
            minChildWeight: 1.0,
            randomSeed: 42
        )
    )

    // Evaluate on test data
    print("\nEvaluating model...")
    let evaluation = regressor.evaluation(on: testData)

    print("Root Mean Squared Error: \(evaluation.rootMeanSquaredError)")
    print("Maximum Error: \(evaluation.maximumError)")

    // Get training metrics
    let trainingMetrics = regressor.trainingMetrics
    print("Training RMSE: \(trainingMetrics.rootMeanSquaredError)")

    // Create model metadata
    let metadata = MLModelMetadata(
        author: "FreshTrack",
        shortDescription: "Predicts food expiration days based on category and storage location",
        version: "1.0.0"
    )

    // Export the model
    let outputPath = "./ExpirationPredictor.mlmodel"
    let outputURL = URL(fileURLWithPath: outputPath)

    print("\nSaving model to: \(outputPath)")
    try regressor.write(to: outputURL, metadata: metadata)

    print("\n✅ Model training complete!")
    print("Add ExpirationPredictor.mlmodel to your Xcode project.")

} catch {
    print("❌ Error: \(error)")
    exit(1)
}

//
//  ReceiptScannerService.swift
//  FreshTrack
//
//  Orchestrates receipt OCR and maps parsed line items to Grocery objects.
//

import Foundation
import UIKit
import SwiftData
import Combine

@MainActor
class ReceiptScannerService: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var isProcessing = false
    @Published var editableItems: [ReceiptLineItem] = []
    @Published var errorMessage: String?
    @Published var processingComplete = false

    private let ocrService = VisionReceiptService.shared

    // MARK: - OCR Processing

    func processReceipt() async {
        guard let image = selectedImage else { return }
        isProcessing = true
        errorMessage = nil
        processingComplete = false

        do {
            let prediction = try await ocrService.processReceipt(image: image)
            editableItems = mapLineItems(prediction.line_items ?? [])
            processingComplete = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    func matchItem(at index: Int) async {
        guard index < editableItems.count else { return }
        editableItems[index].matchStatus = .searching
        let name = editableItems[index].resolvedName
        let offName = await BarcodeAPIService.shared.searchByName(name)
        guard index < editableItems.count else { return }
        if let offName {
            editableItems[index].matchedOFFName = offName
            editableItems[index].resolvedName = offName
            editableItems[index].matchStatus = .matched
        } else {
            editableItems[index].matchStatus = .unmatched
        }
    }

    func confirmItem(at index: Int) {
        guard index < editableItems.count else { return }
        editableItems[index].matchStatus = .confirmed
    }

    // MARK: - SwiftData Insert

    func addGroceries(context: ModelContext) {
        for item in editableItems where item.isSelected && item.isReady {
            let grocery = Grocery(
                name: item.resolvedName,
                category: item.category,
                storageLocation: item.storageLocation,
                quantity: item.quantity
            )
            context.insert(grocery)
        }
        NotificationCenter.default.post(name: .groceriesDidChange, object: nil)
    }

    // MARK: - Reset

    func reset() {
        selectedImage = nil
        isProcessing = false
        editableItems = []
        errorMessage = nil
        processingComplete = false
    }

    // MARK: - Private Helpers

    private func mapLineItems(_ predictions: [LineItemPrediction]) -> [ReceiptLineItem] {
        predictions.compactMap { prediction in
            guard let raw = prediction.description, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let cleaned = cleanDescription(raw)
            guard !cleaned.isEmpty else { return nil }
            let category = guessCategory(from: cleaned)
            return ReceiptLineItem(
                id: UUID().uuidString,
                rawDescription: raw,
                resolvedName: cleaned,
                quantity: prediction.quantity ?? 1.0,
                category: category,
                storageLocation: Grocery.suggestedStorageLocation(for: category),
                isSelected: true,
                matchStatus: .unmatched
            )
        }
    }

    private func cleanDescription(_ raw: String) -> String {
        var result = raw
        // Remove leading barcode-like digit sequences (e.g. "071050315 SUNCHIPS" → "SUNCHIPS")
        if let match = result.range(of: #"^\d{6,}\s+"#, options: .regularExpression) {
            result = String(result[match.upperBound...])
        }
        // Remove trailing tax codes and single letters/digits (e.g. "MILK F", "EGGS 1")
        result = result.replacingOccurrences(of: #"\s+[A-Z]\d?\s*$"#, with: "", options: .regularExpression)
        // Title-case
        result = result.split(separator: " ").map { word in
            let s = String(word)
            return s.prefix(1).uppercased() + s.dropFirst().lowercased()
        }.joined(separator: " ")
        return result.trimmingCharacters(in: .whitespaces)
    }

    private func guessCategory(from name: String) -> FoodCategory {
        let lower = name.lowercased()

        let dairy = ["milk", "cheese", "yogurt", "butter", "cream", "egg", "eggs", "kefir", "sour cream", "cottage"]
        let meat = ["chicken", "beef", "pork", "turkey", "lamb", "steak", "ground", "sausage", "bacon", "ham", "ribs", "brisket", "chop"]
        let seafood = ["fish", "salmon", "tuna", "shrimp", "crab", "lobster", "tilapia", "cod", "halibut", "clam", "oyster"]
        let produce = ["apple", "banana", "orange", "grape", "lettuce", "spinach", "tomato", "onion", "garlic", "pepper", "broccoli", "carrot", "celery", "cucumber", "avocado", "lemon", "lime", "potato", "mushroom", "zucchini", "corn", "strawberr", "blueberr", "raspberr"]
        let bakery = ["bread", "bagel", "muffin", "cake", "cookie", "donut", "roll", "bun", "croissant", "pita", "tortilla", "wrap"]
        let frozen = ["frozen", "ice cream", "popsicle", "pizza", "fries", "nugget", "edamame", "waffle"]
        let beverages = ["juice", "soda", "water", "coffee", "tea", "lemonade", "sports drink", "energy drink", "sparkling", "kombucha", "coke", "pepsi"]
        let condiments = ["sauce", "ketchup", "mustard", "mayo", "mayonnaise", "salad dressing", "vinegar", "oil", "salt", "pepper", "spice", "seasoning", "soy sauce", "hot sauce", "sriracha", "syrup", "jam", "jelly", "peanut butter", "hummus"]
        let snacks = ["chip", "chips", "popcorn", "pretzel", "cracker", "granola", "bar", "trail mix", "nut", "nuts", "candy", "chocolate", "gum", "snack"]
        let pantry = ["pasta", "rice", "bean", "beans", "lentil", "soup", "broth", "stock", "flour", "sugar", "oat", "cereal", "canned", "can of", "jar", "honey", "quinoa", "noodle"]

        if dairy.contains(where: { lower.contains($0) }) { return .dairy }
        if meat.contains(where: { lower.contains($0) }) { return .meat }
        if seafood.contains(where: { lower.contains($0) }) { return .seafood }
        if produce.contains(where: { lower.contains($0) }) { return .produce }
        if bakery.contains(where: { lower.contains($0) }) { return .bakery }
        if frozen.contains(where: { lower.contains($0) }) { return .frozen }
        if beverages.contains(where: { lower.contains($0) }) { return .beverages }
        if condiments.contains(where: { lower.contains($0) }) { return .condiments }
        if snacks.contains(where: { lower.contains($0) }) { return .snacks }
        if pantry.contains(where: { lower.contains($0) }) { return .pantry }

        return .other
    }
}

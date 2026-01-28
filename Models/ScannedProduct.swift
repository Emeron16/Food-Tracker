//
//  ScannedProduct.swift
//  FreshTrack
//
//  Created by Prince Marcelle on 1/27/26.
//

import Foundation

/// Represents a product identified by barcode scanning.
/// Used to pre-fill AddGroceryView with product information.
struct ScannedProduct: Sendable {
    let barcode: String
    let name: String
    let brand: String?
    let suggestedCategory: FoodCategory
    let quantityString: String?
    let imageURL: String?

    /// Display name combining brand and product name
    var displayName: String {
        if let brand = brand, !brand.isEmpty, !name.lowercased().contains(brand.lowercased()) {
            return "\(brand) \(name)"
        }
        return name
    }
}

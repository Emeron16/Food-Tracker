//
//  Grocery.swift
//  FreshTrack
//
//  Created by Prince Marcelle on 1/26/26.
//

import Foundation
import SwiftData

// MARK: - Enums

/// Categories for food items to help with organization and expiration prediction
enum FoodCategory: String, CaseIterable, Codable, Identifiable {
    case dairy = "Dairy"
    case meat = "Meat"
    case seafood = "Seafood"
    case produce = "Produce"
    case bakery = "Bakery"
    case frozen = "Frozen"
    case pantry = "Pantry"
    case beverages = "Beverages"
    case condiments = "Condiments"
    case snacks = "Snacks"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dairy: return "drop.fill"
        case .meat: return "fork.knife"
        case .seafood: return "fish.fill"
        case .produce: return "leaf.fill"
        case .bakery: return "birthday.cake.fill"
        case .frozen: return "snowflake"
        case .pantry: return "cabinet.fill"
        case .beverages: return "cup.and.saucer.fill"
        case .condiments: return "takeoutbag.and.cup.and.straw.fill"
        case .snacks: return "popcorn.fill"
        case .other: return "questionmark.circle.fill"
        }
    }

    /// Default expiration days for each category (used when no ML prediction available)
    var defaultExpirationDays: Int {
        switch self {
        case .dairy: return 14
        case .meat: return 5
        case .seafood: return 3
        case .produce: return 7
        case .bakery: return 5
        case .frozen: return 180
        case .pantry: return 365
        case .beverages: return 30
        case .condiments: return 180
        case .snacks: return 60
        case .other: return 14
        }
    }
}

/// Storage locations for food items
enum StorageLocation: String, CaseIterable, Codable, Identifiable {
    case refrigerator = "Refrigerator"
    case freezer = "Freezer"
    case pantry = "Pantry"
    case counter = "Counter"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .refrigerator: return "refrigerator.fill"
        case .freezer: return "snowflake"
        case .pantry: return "cabinet.fill"
        case .counter: return "table.furniture.fill"
        }
    }
}

/// Measurement units for grocery quantities
enum MeasurementUnit: String, CaseIterable, Codable, Identifiable {
    case piece = "piece"
    case pound = "lb"
    case ounce = "oz"
    case gram = "g"
    case kilogram = "kg"
    case liter = "L"
    case milliliter = "mL"
    case gallon = "gal"
    case cup = "cup"
    case bunch = "bunch"
    case package = "pkg"
    case can = "can"
    case bottle = "bottle"
    case box = "box"
    case bag = "bag"
    case dozen = "dozen"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .piece: return "piece(s)"
        case .pound: return "lb"
        case .ounce: return "oz"
        case .gram: return "g"
        case .kilogram: return "kg"
        case .liter: return "L"
        case .milliliter: return "mL"
        case .gallon: return "gal"
        case .cup: return "cup(s)"
        case .bunch: return "bunch(es)"
        case .package: return "package(s)"
        case .can: return "can(s)"
        case .bottle: return "bottle(s)"
        case .box: return "box(es)"
        case .bag: return "bag(s)"
        case .dozen: return "dozen"
        }
    }
}

/// Expiration status for visual indicators
enum ExpirationStatus {
    case fresh
    case warning    // 3-7 days until expiration
    case critical   // 0-2 days until expiration
    case expired
    case unknown

    var label: String {
        switch self {
        case .fresh: return "Fresh"
        case .warning: return "Use Soon"
        case .critical: return "Expiring"
        case .expired: return "Expired"
        case .unknown: return "Unknown"
        }
    }

    var color: String {
        switch self {
        case .fresh: return "green"
        case .warning: return "orange"
        case .critical: return "red"
        case .expired: return "gray"
        case .unknown: return "secondary"
        }
    }
}

// MARK: - Grocery Model

@Model
final class Grocery {
    var name: String

    // Category stored as raw string for SwiftData compatibility
    var categoryRaw: String
    var storageLocationRaw: String
    var unitRaw: String

    // Dates
    var purchaseDate: Date
    var expirationDate: Date?
    var predictedExpirationDate: Date?

    // Quantity
    var quantity: Double

    // Barcode & external
    var barcode: String?
    var notes: String?
    @Attribute(.externalStorage) var imageData: Data?

    // ML prediction metadata
    var confidenceScore: Double?

    // Consumption tracking
    var isConsumed: Bool
    var consumedDate: Date?

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Type-Safe Computed Properties

    var category: FoodCategory {
        get { FoodCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var storageLocation: StorageLocation {
        get { StorageLocation(rawValue: storageLocationRaw) ?? .refrigerator }
        set { storageLocationRaw = newValue.rawValue }
    }

    var unit: MeasurementUnit {
        get { MeasurementUnit(rawValue: unitRaw) ?? .piece }
        set { unitRaw = newValue.rawValue }
    }

    /// The effective expiration date (user-provided or ML-predicted)
    var effectiveExpirationDate: Date? {
        expirationDate ?? predictedExpirationDate
    }

    /// Days remaining until expiration (negative if expired)
    var daysUntilExpiration: Int? {
        guard let expDate = effectiveExpirationDate else { return nil }
        return Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: expDate)
        ).day
    }

    var isExpired: Bool {
        guard let days = daysUntilExpiration else { return false }
        return days < 0
    }

    /// Current expiration status based on days remaining
    var expirationStatus: ExpirationStatus {
        guard let days = daysUntilExpiration else { return .unknown }
        switch days {
        case ..<0: return .expired
        case 0...2: return .critical
        case 3...7: return .warning
        default: return .fresh
        }
    }

    /// Formatted string for expiration display
    var expirationDisplayText: String {
        guard let days = daysUntilExpiration else {
            return "No expiration date"
        }
        switch days {
        case ..<0:
            return "Expired \(abs(days)) day\(abs(days) == 1 ? "" : "s") ago"
        case 0:
            return "Expires today"
        case 1:
            return "Expires tomorrow"
        default:
            return "Expires in \(days) days"
        }
    }

    /// Formatted quantity string
    var quantityDisplayText: String {
        let formatted = quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", quantity)
            : String(format: "%.1f", quantity)
        return "\(formatted) \(unit.displayName)"
    }

    // MARK: - Initialization

    init(
        name: String,
        category: FoodCategory = .other,
        storageLocation: StorageLocation = .refrigerator,
        quantity: Double = 1.0,
        unit: MeasurementUnit = .piece,
        purchaseDate: Date = Date(),
        expirationDate: Date? = nil,
        predictedExpirationDate: Date? = nil,
        confidenceScore: Double? = nil,
        barcode: String? = nil,
        notes: String? = nil,
        isConsumed: Bool = false,
        consumedDate: Date? = nil
    ) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.storageLocationRaw = storageLocation.rawValue
        self.unitRaw = unit.rawValue
        self.quantity = quantity
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.predictedExpirationDate = predictedExpirationDate
        self.confidenceScore = confidenceScore
        self.barcode = barcode
        self.notes = notes
        self.isConsumed = isConsumed
        self.consumedDate = consumedDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Suggested Storage Location

    /// Returns a sensible default storage location for a given category
    static func suggestedStorageLocation(for category: FoodCategory) -> StorageLocation {
        switch category {
        case .dairy, .meat, .seafood, .produce: return .refrigerator
        case .frozen: return .freezer
        case .bakery: return .counter
        case .pantry, .condiments, .snacks, .beverages: return .pantry
        case .other: return .refrigerator
        }
    }
}

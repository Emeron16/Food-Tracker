import Foundation

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
    case tablespoon = "tbsp"
    case teaspoon = "tsp"
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
        case .tablespoon: return "tbsp"
        case .teaspoon: return "tsp"
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
enum ExpirationStatus: Equatable {
    case fresh
    case warning    // 3-7 days until expiration
    case critical   // 0-2 days until expiration
    case expired
    case unknown

    var color: String {
        switch self {
        case .fresh: return "green"
        case .warning: return "orange"
        case .critical: return "red"
        case .expired: return "gray"
        case .unknown: return "secondary"
        }
    }

    var label: String {
        switch self {
        case .fresh: return "Fresh"
        case .warning: return "Use Soon"
        case .critical: return "Expiring"
        case .expired: return "Expired"
        case .unknown: return "Unknown"
        }
    }
}

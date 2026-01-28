import Foundation

/// Domain model representing a grocery item in the user's pantry
struct GroceryItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var category: FoodCategory
    var purchaseDate: Date
    var expirationDate: Date?
    var predictedExpirationDate: Date?
    var quantity: Double
    var unit: MeasurementUnit
    var storageLocation: StorageLocation
    var barcode: String?
    var notes: String?
    var confidenceScore: Double?
    var isConsumed: Bool
    var consumedDate: Date?

    init(
        id: UUID = UUID(),
        name: String,
        category: FoodCategory,
        purchaseDate: Date = Date(),
        expirationDate: Date? = nil,
        predictedExpirationDate: Date? = nil,
        quantity: Double = 1.0,
        unit: MeasurementUnit = .piece,
        storageLocation: StorageLocation = .refrigerator,
        barcode: String? = nil,
        notes: String? = nil,
        confidenceScore: Double? = nil,
        isConsumed: Bool = false,
        consumedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.predictedExpirationDate = predictedExpirationDate
        self.quantity = quantity
        self.unit = unit
        self.storageLocation = storageLocation
        self.barcode = barcode
        self.notes = notes
        self.confidenceScore = confidenceScore
        self.isConsumed = isConsumed
        self.consumedDate = consumedDate
    }

    /// The effective expiration date (user-provided or ML-predicted)
    var effectiveExpirationDate: Date? {
        expirationDate ?? predictedExpirationDate
    }

    /// Days remaining until expiration (negative if expired)
    var daysUntilExpiration: Int? {
        guard let expDate = effectiveExpirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: expDate)).day
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
        let formattedQuantity = quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", quantity)
            : String(format: "%.1f", quantity)
        return "\(formattedQuantity) \(unit.displayName)"
    }
}

// MARK: - Sample Data for Previews
extension GroceryItem {
    static let sampleItems: [GroceryItem] = [
        GroceryItem(
            name: "Milk",
            category: .dairy,
            purchaseDate: Date().addingTimeInterval(-5 * 24 * 60 * 60),
            expirationDate: Date().addingTimeInterval(2 * 24 * 60 * 60),
            quantity: 1,
            unit: .gallon,
            storageLocation: .refrigerator
        ),
        GroceryItem(
            name: "Chicken Breast",
            category: .meat,
            purchaseDate: Date().addingTimeInterval(-2 * 24 * 60 * 60),
            predictedExpirationDate: Date().addingTimeInterval(1 * 24 * 60 * 60),
            quantity: 2,
            unit: .pound,
            storageLocation: .refrigerator,
            confidenceScore: 0.85
        ),
        GroceryItem(
            name: "Bananas",
            category: .produce,
            purchaseDate: Date().addingTimeInterval(-3 * 24 * 60 * 60),
            expirationDate: Date().addingTimeInterval(4 * 24 * 60 * 60),
            quantity: 6,
            unit: .piece,
            storageLocation: .counter
        ),
        GroceryItem(
            name: "Bread",
            category: .bakery,
            purchaseDate: Date().addingTimeInterval(-4 * 24 * 60 * 60),
            expirationDate: Date().addingTimeInterval(-1 * 24 * 60 * 60),
            quantity: 1,
            unit: .package,
            storageLocation: .pantry
        ),
        GroceryItem(
            name: "Frozen Pizza",
            category: .frozen,
            purchaseDate: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            expirationDate: Date().addingTimeInterval(150 * 24 * 60 * 60),
            quantity: 2,
            unit: .box,
            storageLocation: .freezer
        )
    ]
}

import Foundation
import SwiftData

/// SwiftData persistent model for grocery items
@Model
final class GroceryItemEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRaw: String
    var purchaseDate: Date
    var expirationDate: Date?
    var predictedExpirationDate: Date?
    var quantity: Double
    var unitRaw: String
    var storageLocationRaw: String
    var barcode: String?
    var notes: String?
    @Attribute(.externalStorage) var imageData: Data?
    var confidenceScore: Double?
    var isConsumed: Bool
    var consumedDate: Date?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Properties for Type-Safe Access

    var category: FoodCategory {
        get { FoodCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var unit: MeasurementUnit {
        get { MeasurementUnit(rawValue: unitRaw) ?? .piece }
        set { unitRaw = newValue.rawValue }
    }

    var storageLocation: StorageLocation {
        get { StorageLocation(rawValue: storageLocationRaw) ?? .refrigerator }
        set { storageLocationRaw = newValue.rawValue }
    }

    // MARK: - Initialization

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
        imageData: Data? = nil,
        confidenceScore: Double? = nil,
        isConsumed: Bool = false,
        consumedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.predictedExpirationDate = predictedExpirationDate
        self.quantity = quantity
        self.unitRaw = unit.rawValue
        self.storageLocationRaw = storageLocation.rawValue
        self.barcode = barcode
        self.notes = notes
        self.imageData = imageData
        self.confidenceScore = confidenceScore
        self.isConsumed = isConsumed
        self.consumedDate = consumedDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Convenience Methods

    /// Update the entity from a domain model
    func update(from item: GroceryItem) {
        self.name = item.name
        self.categoryRaw = item.category.rawValue
        self.purchaseDate = item.purchaseDate
        self.expirationDate = item.expirationDate
        self.predictedExpirationDate = item.predictedExpirationDate
        self.quantity = item.quantity
        self.unitRaw = item.unit.rawValue
        self.storageLocationRaw = item.storageLocation.rawValue
        self.barcode = item.barcode
        self.notes = item.notes
        self.confidenceScore = item.confidenceScore
        self.isConsumed = item.isConsumed
        self.consumedDate = item.consumedDate
        self.updatedAt = Date()
    }

    /// Convert to domain model
    func toDomainModel() -> GroceryItem {
        GroceryItem(
            id: id,
            name: name,
            category: category,
            purchaseDate: purchaseDate,
            expirationDate: expirationDate,
            predictedExpirationDate: predictedExpirationDate,
            quantity: quantity,
            unit: unit,
            storageLocation: storageLocation,
            barcode: barcode,
            notes: notes,
            confidenceScore: confidenceScore,
            isConsumed: isConsumed,
            consumedDate: consumedDate
        )
    }

    /// Create entity from domain model
    static func from(_ item: GroceryItem) -> GroceryItemEntity {
        GroceryItemEntity(
            id: item.id,
            name: item.name,
            category: item.category,
            purchaseDate: item.purchaseDate,
            expirationDate: item.expirationDate,
            predictedExpirationDate: item.predictedExpirationDate,
            quantity: item.quantity,
            unit: item.unit,
            storageLocation: item.storageLocation,
            barcode: item.barcode,
            notes: item.notes,
            confidenceScore: item.confidenceScore,
            isConsumed: item.isConsumed,
            consumedDate: item.consumedDate
        )
    }
}

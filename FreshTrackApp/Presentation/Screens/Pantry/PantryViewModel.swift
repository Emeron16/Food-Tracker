import Foundation
import SwiftData
import Observation

/// ViewModel for the Pantry screen
@Observable
@MainActor
final class PantryViewModel {
    // MARK: - State

    private(set) var groceries: [GroceryItem] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var searchText = ""
    var selectedCategory: FoodCategory?
    var selectedLocation: StorageLocation?
    var sortOption: SortOption = .expirationDate

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Computed Properties

    var filteredGroceries: [GroceryItem] {
        var result = groceries.filter { !$0.isConsumed }

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply category filter
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // Apply location filter
        if let location = selectedLocation {
            result = result.filter { $0.storageLocation == location }
        }

        // Apply sorting
        return sortGroceries(result)
    }

    var expiringItems: [GroceryItem] {
        groceries
            .filter { !$0.isConsumed }
            .filter { $0.expirationStatus == .critical || $0.expirationStatus == .warning }
            .sorted { ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999) }
    }

    var expiredItems: [GroceryItem] {
        groceries
            .filter { !$0.isConsumed }
            .filter { $0.expirationStatus == .expired }
    }

    var groceriesByCategory: [FoodCategory: [GroceryItem]] {
        Dictionary(grouping: filteredGroceries) { $0.category }
    }

    var groceriesByLocation: [StorageLocation: [GroceryItem]] {
        Dictionary(grouping: filteredGroceries) { $0.storageLocation }
    }

    var totalItemCount: Int {
        groceries.filter { !$0.isConsumed }.count
    }

    // MARK: - Actions

    func loadGroceries() async {
        isLoading = true
        errorMessage = nil

        do {
            let descriptor = FetchDescriptor<GroceryItemEntity>(
                sortBy: [SortDescriptor(\.purchaseDate, order: .reverse)]
            )

            let entities = try modelContext.fetch(descriptor)
            groceries = entities.map { $0.toDomainModel() }
        } catch {
            errorMessage = "Failed to load groceries: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func addGrocery(_ item: GroceryItem) async {
        let entity = GroceryItemEntity.from(item)
        modelContext.insert(entity)

        do {
            try modelContext.save()
            await loadGroceries()
        } catch {
            errorMessage = "Failed to save grocery: \(error.localizedDescription)"
        }
    }

    func updateGrocery(_ item: GroceryItem) async {
        let descriptor = FetchDescriptor<GroceryItemEntity>(
            predicate: #Predicate { $0.id == item.id }
        )

        do {
            if let entity = try modelContext.fetch(descriptor).first {
                entity.update(from: item)
                try modelContext.save()
                await loadGroceries()
            }
        } catch {
            errorMessage = "Failed to update grocery: \(error.localizedDescription)"
        }
    }

    func deleteGrocery(_ item: GroceryItem) async {
        let descriptor = FetchDescriptor<GroceryItemEntity>(
            predicate: #Predicate { $0.id == item.id }
        )

        do {
            if let entity = try modelContext.fetch(descriptor).first {
                modelContext.delete(entity)
                try modelContext.save()
                await loadGroceries()
            }
        } catch {
            errorMessage = "Failed to delete grocery: \(error.localizedDescription)"
        }
    }

    func markAsConsumed(_ item: GroceryItem) async {
        var updatedItem = item
        updatedItem.isConsumed = true
        updatedItem.consumedDate = Date()
        await updateGrocery(updatedItem)
    }

    func clearFilters() {
        searchText = ""
        selectedCategory = nil
        selectedLocation = nil
    }

    // MARK: - Private Helpers

    private func sortGroceries(_ groceries: [GroceryItem]) -> [GroceryItem] {
        switch sortOption {
        case .expirationDate:
            return groceries.sorted {
                ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999)
            }
        case .name:
            return groceries.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .category:
            return groceries.sorted { $0.category.rawValue < $1.category.rawValue }
        case .purchaseDate:
            return groceries.sorted { $0.purchaseDate > $1.purchaseDate }
        case .quantity:
            return groceries.sorted { $0.quantity > $1.quantity }
        }
    }
}

// MARK: - Sort Options

enum SortOption: String, CaseIterable, Identifiable {
    case expirationDate = "Expiration Date"
    case name = "Name"
    case category = "Category"
    case purchaseDate = "Purchase Date"
    case quantity = "Quantity"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .expirationDate: return "calendar.badge.clock"
        case .name: return "textformat.abc"
        case .category: return "folder"
        case .purchaseDate: return "cart"
        case .quantity: return "number"
        }
    }
}

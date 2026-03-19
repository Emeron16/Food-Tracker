//
//  PantryView.swift
//  FreshTrack
//
//  Created by Prince Marcelle on 1/26/26.
//

import SwiftUI
import SwiftData

enum PantrySortOption: String, CaseIterable {
    case name           = "Name"
    case dateAdded      = "Date Added"
    case category       = "Category"
    case storageLocation = "Storage Location"
    case purchaseDate   = "Purchase Date"
    case expirationDate = "Expiration Date"

    var icon: String {
        switch self {
        case .name:            return "textformat.abc"
        case .dateAdded:       return "calendar.badge.plus"
        case .category:        return "square.grid.2x2"
        case .storageLocation: return "archivebox"
        case .purchaseDate:    return "cart"
        case .expirationDate:  return "clock"
        }
    }
}

struct PantryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Grocery> { !$0.isConsumed },
        sort: \Grocery.createdAt,
        order: .reverse
    ) private var groceries: [Grocery]
    @State private var showingAddGrocery = false
    @State private var searchText = ""
    @State private var groceryToEdit: Grocery?
    @State private var sortOption: PantrySortOption = .dateAdded

    private var sortedGroceries: [Grocery] {
        groceries.sorted { a, b in
            switch sortOption {
            case .name:
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .dateAdded:
                return a.createdAt > b.createdAt
            case .category:
                return a.category.rawValue.localizedCaseInsensitiveCompare(b.category.rawValue) == .orderedAscending
            case .storageLocation:
                return a.storageLocation.rawValue.localizedCaseInsensitiveCompare(b.storageLocation.rawValue) == .orderedAscending
            case .purchaseDate:
                return a.purchaseDate > b.purchaseDate
            case .expirationDate:
                let aDate = a.expirationDate ?? a.predictedExpirationDate ?? .distantFuture
                let bDate = b.expirationDate ?? b.predictedExpirationDate ?? .distantFuture
                return aDate < bDate
            }
        }
    }

    private var filteredGroceries: [Grocery] {
        if searchText.isEmpty {
            return sortedGroceries
        }
        return sortedGroceries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var expiringItems: [Grocery] {
        groceries.filter {
            $0.expirationStatus == .critical || $0.expirationStatus == .warning
        }.sorted {
            ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Expiring soon section
                if !expiringItems.isEmpty && searchText.isEmpty {
                    Section {
                        ForEach(expiringItems.prefix(3)) { grocery in
                            GroceryRowView(grocery: grocery)
                                .contentShape(Rectangle())
                                .onTapGesture { groceryToEdit = grocery }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Expiring Soon")
                        }
                    }
                }

                // All items
                Section {
                    ForEach(filteredGroceries) { grocery in
                        GroceryRowView(grocery: grocery)
                            .contentShape(Rectangle())
                            .onTapGesture { groceryToEdit = grocery }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteGrocery(grocery)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    markConsumed(grocery)
                                } label: {
                                    Label("Used", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                    }
                } header: {
                    HStack {
                        Text("All Items")
                        Spacer()
                        Text("\(filteredGroceries.count) items")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search groceries")
            .navigationTitle("Pantry")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(PantrySortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option
                            } label: {
                                Label(option.rawValue, systemImage: option.icon)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(sortOption.rawValue)
                                .font(.subheadline)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddGrocery = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#else
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGrocery = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#endif
            }
            .sheet(isPresented: $showingAddGrocery) {
                AddGroceryView()
            }
            .sheet(item: $groceryToEdit) { grocery in
                EditGroceryView(grocery: grocery)
            }
            .overlay {
                if groceries.isEmpty {
                    ContentUnavailableView {
                        Label("No Groceries", systemImage: "refrigerator")
                    } description: {
                        Text("Add groceries to start tracking their expiration dates")
                    } actions: {
                        Button {
                            showingAddGrocery = true
                        } label: {
                            Text("Add Grocery")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private func deleteGrocery(_ grocery: Grocery) {
        withAnimation {
            ExpirationNotificationService.shared.removeNotifications(for: grocery)
            modelContext.delete(grocery)
        }
        notifyGroceriesChanged()
    }

    private func markConsumed(_ grocery: Grocery) {
        withAnimation {
            grocery.isConsumed = true
            grocery.consumedDate = Date()
            grocery.updatedAt = Date()
            ExpirationNotificationService.shared.removeNotifications(for: grocery)
        }
        notifyGroceriesChanged()
    }

    private func notifyGroceriesChanged() {
        NotificationCenter.default.post(name: .groceriesDidChange, object: nil)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Grocery.self, configurations: config)

    return PantryView()
        .modelContainer(container)
}

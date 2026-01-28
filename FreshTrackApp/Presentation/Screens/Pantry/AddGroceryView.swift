import SwiftUI

/// Sheet view for adding a new grocery item
struct AddGroceryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: FoodCategory = .other
    @State private var storageLocation: StorageLocation = .refrigerator
    @State private var quantity: Double = 1
    @State private var unit: MeasurementUnit = .piece
    @State private var purchaseDate = Date()
    @State private var hasExpirationDate = false
    @State private var expirationDate = Date().addingTimeInterval(7 * 24 * 60 * 60)
    @State private var notes = ""
    @State private var barcode: String?

    let onSave: (GroceryItem) -> Void

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info Section
                Section("Item Details") {
                    TextField("Item Name", text: $name)
                        .textInputAutocapitalization(.words)

                    Picker("Category", selection: $category) {
                        ForEach(FoodCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .onChange(of: category) { _, newCategory in
                        // Update default expiration based on category
                        if !hasExpirationDate {
                            let defaultDays = newCategory.defaultExpirationDays
                            expirationDate = purchaseDate.addingTimeInterval(Double(defaultDays) * 24 * 60 * 60)
                        }

                        // Suggest storage location based on category
                        storageLocation = suggestedStorageLocation(for: newCategory)
                    }

                    Picker("Storage Location", selection: $storageLocation) {
                        ForEach(StorageLocation.allCases) { location in
                            Label(location.rawValue, systemImage: location.icon)
                                .tag(location)
                        }
                    }
                }

                // Quantity Section
                Section("Quantity") {
                    HStack {
                        Text("Amount")
                        Spacer()

                        HStack(spacing: 12) {
                            Button {
                                if quantity > 1 {
                                    quantity -= 1
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)

                            TextField("Qty", value: $quantity, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 50)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            Button {
                                quantity += 1
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Picker("Unit", selection: $unit) {
                        ForEach(MeasurementUnit.allCases) { u in
                            Text(u.displayName).tag(u)
                        }
                    }
                }

                // Dates Section
                Section("Dates") {
                    DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                        .onChange(of: purchaseDate) { _, newDate in
                            if !hasExpirationDate {
                                let defaultDays = category.defaultExpirationDays
                                expirationDate = newDate.addingTimeInterval(Double(defaultDays) * 24 * 60 * 60)
                            }
                        }

                    Toggle("Set Expiration Date", isOn: $hasExpirationDate)

                    if hasExpirationDate {
                        DatePicker("Expiration Date", selection: $expirationDate, displayedComponents: .date)
                    } else {
                        HStack {
                            Text("Estimated Expiration")
                            Spacer()
                            Text(estimatedExpirationDate, style: .date)
                                .foregroundStyle(.secondary)
                        }

                        Text("Based on \(category.rawValue) category default (\(category.defaultExpirationDays) days)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Optional Section
                Section("Additional Info (Optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)

                    if let barcode {
                        HStack {
                            Text("Barcode")
                            Spacer()
                            Text(barcode)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Quick Add Suggestions
                if name.isEmpty {
                    Section("Quick Add") {
                        quickAddSuggestions
                    }
                }
            }
            .navigationTitle("Add Grocery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveItem()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var estimatedExpirationDate: Date {
        purchaseDate.addingTimeInterval(Double(category.defaultExpirationDays) * 24 * 60 * 60)
    }

    // MARK: - Quick Add Suggestions

    private var quickAddSuggestions: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(commonItems, id: \.name) { suggestion in
                quickAddButton(suggestion)
            }
        }
        .padding(.vertical, 4)
    }

    private func quickAddButton(_ suggestion: QuickAddSuggestion) -> some View {
        Button {
            name = suggestion.name
            category = suggestion.category
            storageLocation = suggestedStorageLocation(for: suggestion.category)
            unit = suggestion.unit
        } label: {
            VStack(spacing: 4) {
                Image(systemName: suggestion.category.icon)
                    .font(.title3)
                Text(suggestion.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var commonItems: [QuickAddSuggestion] {
        [
            QuickAddSuggestion(name: "Milk", category: .dairy, unit: .gallon),
            QuickAddSuggestion(name: "Eggs", category: .dairy, unit: .dozen),
            QuickAddSuggestion(name: "Bread", category: .bakery, unit: .package),
            QuickAddSuggestion(name: "Chicken", category: .meat, unit: .pound),
            QuickAddSuggestion(name: "Apples", category: .produce, unit: .piece),
            QuickAddSuggestion(name: "Bananas", category: .produce, unit: .bunch),
            QuickAddSuggestion(name: "Cheese", category: .dairy, unit: .package),
            QuickAddSuggestion(name: "Yogurt", category: .dairy, unit: .piece),
            QuickAddSuggestion(name: "Lettuce", category: .produce, unit: .piece),
        ]
    }

    // MARK: - Helper Methods

    private func suggestedStorageLocation(for category: FoodCategory) -> StorageLocation {
        switch category {
        case .dairy, .meat, .seafood: return .refrigerator
        case .produce: return .refrigerator
        case .frozen: return .freezer
        case .bakery: return .counter
        case .pantry, .condiments, .snacks, .beverages: return .pantry
        case .other: return storageLocation // Keep current selection
        }
    }

    private func saveItem() {
        let item = GroceryItem(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
            purchaseDate: purchaseDate,
            expirationDate: hasExpirationDate ? expirationDate : nil,
            predictedExpirationDate: hasExpirationDate ? nil : estimatedExpirationDate,
            quantity: quantity,
            unit: unit,
            storageLocation: storageLocation,
            barcode: barcode,
            notes: notes.isEmpty ? nil : notes,
            confidenceScore: hasExpirationDate ? nil : 0.75 // Default confidence for category-based prediction
        )

        onSave(item)
        dismiss()
    }
}

// MARK: - Quick Add Suggestion Model

private struct QuickAddSuggestion {
    let name: String
    let category: FoodCategory
    let unit: MeasurementUnit
}

// MARK: - Preview

#Preview {
    AddGroceryView { item in
        print("Added: \(item.name)")
    }
}

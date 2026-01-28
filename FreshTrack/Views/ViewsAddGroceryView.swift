//
//  AddGroceryView.swift
//  FreshTrack
//
//  Created by Prince Marcelle on 1/26/26.
//

import SwiftUI
import SwiftData

struct AddGroceryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var category: FoodCategory
    @State private var storageLocation: StorageLocation
    @State private var quantity: Double
    @State private var unit: MeasurementUnit
    @State private var purchaseDate: Date
    @State private var hasExpirationDate: Bool
    @State private var expirationDate: Date
    @State private var notes: String
    @State private var barcode: String?

    /// Default initializer (no pre-fill)
    init() {
        _name = State(initialValue: "")
        _category = State(initialValue: .other)
        _storageLocation = State(initialValue: .refrigerator)
        _quantity = State(initialValue: 1)
        _unit = State(initialValue: .piece)
        _purchaseDate = State(initialValue: Date())
        _hasExpirationDate = State(initialValue: false)
        _expirationDate = State(initialValue: Date().addingTimeInterval(7 * 24 * 60 * 60))
        _notes = State(initialValue: "")
        _barcode = State(initialValue: nil)
    }

    /// Pre-fill initializer for barcode scanning
    init(scannedProduct: ScannedProduct?, barcode: String? = nil) {
        if let product = scannedProduct {
            _name = State(initialValue: product.displayName)
            _category = State(initialValue: product.suggestedCategory)
            _storageLocation = State(initialValue: Grocery.suggestedStorageLocation(for: product.suggestedCategory))
            _quantity = State(initialValue: 1)
            _unit = State(initialValue: .piece)
            _purchaseDate = State(initialValue: Date())
            _hasExpirationDate = State(initialValue: false)
            _expirationDate = State(initialValue: Date().addingTimeInterval(
                Double(product.suggestedCategory.defaultExpirationDays) * 24 * 60 * 60
            ))
            _notes = State(initialValue: "")
            _barcode = State(initialValue: product.barcode)
        } else {
            _name = State(initialValue: "")
            _category = State(initialValue: .other)
            _storageLocation = State(initialValue: .refrigerator)
            _quantity = State(initialValue: 1)
            _unit = State(initialValue: .piece)
            _purchaseDate = State(initialValue: Date())
            _hasExpirationDate = State(initialValue: false)
            _expirationDate = State(initialValue: Date().addingTimeInterval(7 * 24 * 60 * 60))
            _notes = State(initialValue: "")
            _barcode = State(initialValue: barcode)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Name", text: $name)
#if os(iOS)
                        .textInputAutocapitalization(.words)
#endif

                    Picker("Category", selection: $category) {
                        ForEach(FoodCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .onChange(of: category) { _, newCategory in
                        storageLocation = Grocery.suggestedStorageLocation(for: newCategory)
                        if !hasExpirationDate {
                            expirationDate = purchaseDate.addingTimeInterval(
                                Double(newCategory.defaultExpirationDays) * 24 * 60 * 60
                            )
                        }
                    }

                    Picker("Storage Location", selection: $storageLocation) {
                        ForEach(StorageLocation.allCases) { location in
                            Label(location.rawValue, systemImage: location.icon)
                                .tag(location)
                        }
                    }
                }

                Section("Quantity") {
                    HStack {
                        Text("Amount")
                        Spacer()
                        HStack(spacing: 12) {
                            Button {
                                if quantity > 1 { quantity -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)

                            TextField("Qty", value: $quantity, format: .number)
#if os(iOS)
                                .keyboardType(.decimalPad)
#endif
                                .multilineTextAlignment(.center)
                                .frame(width: 50)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

                            Button {
                                quantity += 1
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.tint)
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

                Section("Dates") {
                    DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                        .onChange(of: purchaseDate) { _, newDate in
                            if !hasExpirationDate {
                                expirationDate = newDate.addingTimeInterval(
                                    Double(category.defaultExpirationDays) * 24 * 60 * 60
                                )
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
                        Text("Based on \(category.rawValue) default (\(category.defaultExpirationDays) days)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notes (Optional)") {
#if os(iOS)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
#else
                    TextField("Notes", text: $notes)
#endif
                }

                if name.isEmpty {
                    Section("Quick Add") {
                        quickAddGrid
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Grocery")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGrocery()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
#else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        saveGrocery()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
#endif
            }
        }
    }

    // MARK: - Computed Properties

    private var estimatedExpirationDate: Date {
        purchaseDate.addingTimeInterval(Double(category.defaultExpirationDays) * 24 * 60 * 60)
    }

    // MARK: - Quick Add Grid

    private var quickAddGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            quickAddButton("Milk", category: .dairy, unit: .gallon)
            quickAddButton("Eggs", category: .dairy, unit: .dozen)
            quickAddButton("Bread", category: .bakery, unit: .package)
            quickAddButton("Chicken", category: .meat, unit: .pound)
            quickAddButton("Apples", category: .produce, unit: .piece)
            quickAddButton("Bananas", category: .produce, unit: .bunch)
            quickAddButton("Cheese", category: .dairy, unit: .package)
            quickAddButton("Yogurt", category: .dairy, unit: .piece)
            quickAddButton("Lettuce", category: .produce, unit: .piece)
        }
        .padding(.vertical, 4)
    }

    private func quickAddButton(_ itemName: String, category cat: FoodCategory, unit u: MeasurementUnit) -> some View {
        Button {
            name = itemName
            category = cat
            unit = u
            storageLocation = Grocery.suggestedStorageLocation(for: cat)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: cat.icon)
                    .font(.title3)
                Text(itemName)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private func saveGrocery() {
        let newGrocery = Grocery(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
            storageLocation: storageLocation,
            quantity: quantity,
            unit: unit,
            purchaseDate: purchaseDate,
            expirationDate: hasExpirationDate ? expirationDate : nil,
            predictedExpirationDate: hasExpirationDate ? nil : estimatedExpirationDate,
            confidenceScore: hasExpirationDate ? nil : 0.75,
            barcode: barcode,
            notes: notes.isEmpty ? nil : notes
        )
        modelContext.insert(newGrocery)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Grocery.self, configurations: config)
    
    return AddGroceryView()
        .modelContainer(container)
}

//
//  EditGroceryView.swift
//  FreshTrack
//
//  Created by Claude on 1/28/26.
//

import SwiftUI
import SwiftData

struct EditGroceryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var grocery: Grocery

    @State private var name: String
    @State private var category: FoodCategory
    @State private var storageLocation: StorageLocation
    @State private var quantity: Double
    @State private var unit: MeasurementUnit
    @State private var purchaseDate: Date
    @State private var hasExpirationDate: Bool
    @State private var expirationDate: Date
    @State private var notes: String

    init(grocery: Grocery) {
        self.grocery = grocery
        _name = State(initialValue: grocery.name)
        _category = State(initialValue: grocery.category)
        _storageLocation = State(initialValue: grocery.storageLocation)
        _quantity = State(initialValue: grocery.quantity)
        _unit = State(initialValue: grocery.unit)
        _purchaseDate = State(initialValue: grocery.purchaseDate)
        _hasExpirationDate = State(initialValue: grocery.expirationDate != nil)
        _expirationDate = State(initialValue: grocery.expirationDate ?? grocery.predictedExpirationDate ?? Date())
        _notes = State(initialValue: grocery.notes ?? "")
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

                // Info section
                Section {
                    if let barcode = grocery.barcode {
                        HStack {
                            Text("Barcode")
                            Spacer()
                            Text(barcode)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Text("Added")
                        Spacer()
                        Text(grocery.createdAt, style: .date)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Grocery")
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
                        saveChanges()
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
                        saveChanges()
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

    // MARK: - Save Changes

    private func saveChanges() {
        grocery.name = name.trimmingCharacters(in: .whitespaces)
        grocery.category = category
        grocery.storageLocation = storageLocation
        grocery.quantity = quantity
        grocery.unit = unit
        grocery.purchaseDate = purchaseDate
        grocery.notes = notes.isEmpty ? nil : notes
        grocery.updatedAt = Date()

        if hasExpirationDate {
            grocery.expirationDate = expirationDate
            grocery.predictedExpirationDate = nil
            grocery.confidenceScore = nil
        } else {
            grocery.expirationDate = nil
            grocery.predictedExpirationDate = estimatedExpirationDate
            grocery.confidenceScore = 0.75
        }

        // Notify to refresh notifications
        NotificationCenter.default.post(name: .groceriesDidChange, object: nil)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Grocery.self, configurations: config)

    let sampleGrocery = Grocery(
        name: "Milk",
        category: .dairy,
        storageLocation: .refrigerator,
        quantity: 1,
        unit: .gallon,
        purchaseDate: Date(),
        expirationDate: Date().addingTimeInterval(7 * 24 * 60 * 60)
    )
    container.mainContext.insert(sampleGrocery)

    return EditGroceryView(grocery: sampleGrocery)
        .modelContainer(container)
}

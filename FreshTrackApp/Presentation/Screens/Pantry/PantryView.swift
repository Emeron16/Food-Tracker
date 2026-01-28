import SwiftUI
import SwiftData

/// Main pantry view showing all grocery items
struct PantryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PantryViewModel?
    @State private var showingAddSheet = false
    @State private var selectedItem: GroceryItem?
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: GroceryItem?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    pantryContent(viewModel: viewModel)
                } else {
                    ProgressView("Loading...")
                }
            }
            .navigationTitle("Pantry")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    if let viewModel {
                        sortMenu(viewModel: viewModel)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                if let viewModel {
                    AddGroceryView { item in
                        Task {
                            await viewModel.addGrocery(item)
                        }
                    }
                }
            }
            .sheet(item: $selectedItem) { item in
                GroceryDetailView(item: item) { updatedItem in
                    if let viewModel {
                        Task {
                            await viewModel.updateGrocery(updatedItem)
                        }
                    }
                }
            }
            .alert("Delete Item", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete, let viewModel {
                        Task {
                            await viewModel.deleteGrocery(item)
                        }
                    }
                }
            } message: {
                if let item = itemToDelete {
                    Text("Are you sure you want to delete \"\(item.name)\"?")
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = PantryViewModel(modelContext: modelContext)
            }
            await viewModel?.loadGroceries()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func pantryContent(viewModel: PantryViewModel) -> some View {
        VStack(spacing: 0) {
            // Search and filters
            searchAndFilters(viewModel: viewModel)

            if viewModel.filteredGroceries.isEmpty {
                emptyState(viewModel: viewModel)
            } else {
                groceryList(viewModel: viewModel)
            }
        }
    }

    private func searchAndFilters(viewModel: PantryViewModel) -> some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search groceries...", text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                ))
                .textFieldStyle(.plain)

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Location filter
                    Menu {
                        Button("All Locations") {
                            viewModel.selectedLocation = nil
                        }
                        Divider()
                        ForEach(StorageLocation.allCases) { location in
                            Button {
                                viewModel.selectedLocation = location
                            } label: {
                                Label(location.rawValue, systemImage: location.icon)
                            }
                        }
                    } label: {
                        filterChip(
                            title: viewModel.selectedLocation?.rawValue ?? "Location",
                            isActive: viewModel.selectedLocation != nil
                        )
                    }

                    // Category filter
                    Menu {
                        Button("All Categories") {
                            viewModel.selectedCategory = nil
                        }
                        Divider()
                        ForEach(FoodCategory.allCases) { category in
                            Button {
                                viewModel.selectedCategory = category
                            } label: {
                                Label(category.rawValue, systemImage: category.icon)
                            }
                        }
                    } label: {
                        filterChip(
                            title: viewModel.selectedCategory?.rawValue ?? "Category",
                            isActive: viewModel.selectedCategory != nil
                        )
                    }

                    // Clear filters
                    if viewModel.selectedLocation != nil || viewModel.selectedCategory != nil {
                        Button {
                            viewModel.clearFilters()
                        } label: {
                            Text("Clear")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func filterChip(title: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(.caption)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.quaternary)
        .foregroundStyle(isActive ? .accent : .primary)
        .clipShape(Capsule())
    }

    private func groceryList(viewModel: PantryViewModel) -> some View {
        List {
            // Expiring soon section
            if !viewModel.expiringItems.isEmpty && viewModel.selectedCategory == nil && viewModel.selectedLocation == nil {
                Section {
                    ForEach(viewModel.expiringItems.prefix(3)) { item in
                        GroceryItemRow(
                            item: item,
                            onConsume: {
                                Task { await viewModel.markAsConsumed(item) }
                            },
                            onDelete: {
                                itemToDelete = item
                                showingDeleteAlert = true
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = item
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Expiring Soon")
                    }
                }
            }

            // All items section
            Section {
                ForEach(viewModel.filteredGroceries) { item in
                    GroceryItemRow(
                        item: item,
                        onConsume: {
                            Task { await viewModel.markAsConsumed(item) }
                        },
                        onDelete: {
                            itemToDelete = item
                            showingDeleteAlert = true
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedItem = item
                    }
                }
            } header: {
                HStack {
                    Text("All Items")
                    Spacer()
                    Text("\(viewModel.filteredGroceries.count) items")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.loadGroceries()
        }
    }

    private func emptyState(viewModel: PantryViewModel) -> some View {
        ContentUnavailableView {
            Label(
                viewModel.searchText.isEmpty ? "No Items" : "No Results",
                systemImage: viewModel.searchText.isEmpty ? "refrigerator" : "magnifyingglass"
            )
        } description: {
            if viewModel.searchText.isEmpty {
                Text("Add groceries to start tracking their expiration dates")
            } else {
                Text("Try adjusting your search or filters")
            }
        } actions: {
            if viewModel.searchText.isEmpty {
                Button {
                    showingAddSheet = true
                } label: {
                    Text("Add Grocery")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    viewModel.clearFilters()
                } label: {
                    Text("Clear Filters")
                }
            }
        }
    }

    private func sortMenu(viewModel: PantryViewModel) -> some View {
        Menu {
            ForEach(SortOption.allCases) { option in
                Button {
                    viewModel.sortOption = option
                } label: {
                    HStack {
                        Label(option.rawValue, systemImage: option.icon)
                        if viewModel.sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }
}

// MARK: - Grocery Detail View

struct GroceryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: GroceryItem
    let onSave: (GroceryItem) -> Void

    init(item: GroceryItem, onSave: @escaping (GroceryItem) -> Void) {
        self._item = State(initialValue: item)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $item.name)

                    Picker("Category", selection: $item.category) {
                        ForEach(FoodCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }

                    Picker("Storage", selection: $item.storageLocation) {
                        ForEach(StorageLocation.allCases) { location in
                            Label(location.rawValue, systemImage: location.icon)
                                .tag(location)
                        }
                    }
                }

                Section("Quantity") {
                    HStack {
                        TextField("Quantity", value: $item.quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)

                        Picker("Unit", selection: $item.unit) {
                            ForEach(MeasurementUnit.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                    }
                }

                Section("Dates") {
                    DatePicker("Purchase Date", selection: $item.purchaseDate, displayedComponents: .date)

                    if let expDate = item.expirationDate {
                        DatePicker(
                            "Expiration Date",
                            selection: Binding(
                                get: { expDate },
                                set: { item.expirationDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    } else if let predDate = item.predictedExpirationDate {
                        HStack {
                            Text("Predicted Expiration")
                            Spacer()
                            Text(predDate, style: .date)
                                .foregroundStyle(.secondary)
                        }

                        if let confidence = item.confidenceScore {
                            HStack {
                                Text("ML Confidence")
                                Spacer()
                                Text("\(Int(confidence * 100))%")
                                    .foregroundStyle(.purple)
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: Binding(
                        get: { item.notes ?? "" },
                        set: { item.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }

                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(item.expirationStatus.label)
                            .foregroundStyle(statusColor)
                    }

                    if let days = item.daysUntilExpiration {
                        HStack {
                            Text("Days Until Expiration")
                            Spacer()
                            Text("\(days)")
                                .foregroundStyle(statusColor)
                        }
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(item)
                        dismiss()
                    }
                    .disabled(item.name.isEmpty)
                }
            }
        }
    }

    private var statusColor: Color {
        switch item.expirationStatus {
        case .fresh: return .green
        case .warning: return .orange
        case .critical: return .red
        case .expired: return .gray
        case .unknown: return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    PantryView()
        .modelContainer(DataContainer.preview)
}

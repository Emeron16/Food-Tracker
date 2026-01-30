//
//  HomeView.swift
//  FreshTrack
//
//  Created by Prince Marcelle on 1/27/26.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Grocery> { !$0.isConsumed },
        sort: \Grocery.purchaseDate,
        order: .reverse
    ) private var activeGroceries: [Grocery]

    @Query(
        filter: #Predicate<Grocery> { $0.isConsumed }
    ) private var consumedGroceries: [Grocery]

    @State private var showingAddGrocery = false
    @State private var selectedStorageLocation: StorageLocation?
    @State private var selectedCategory: FoodCategory?
    @State private var showingTotalItems = false
    @State private var showingExpiringSoon = false
    @State private var showingExpired = false
    @State private var showingConsumed = false

    // MARK: - Computed Properties

    /// Get groceries filtered by storage location
    private func groceries(for location: StorageLocation) -> [Grocery] {
        activeGroceries.filter { $0.storageLocation == location }
            .sorted { ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999) }
    }

    /// Get groceries filtered by category
    private func groceries(for category: FoodCategory) -> [Grocery] {
        activeGroceries.filter { $0.category == category }
            .sorted { ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999) }
    }

    private var expiringSoonItems: [Grocery] {
        activeGroceries.filter {
            $0.expirationStatus == .critical || $0.expirationStatus == .warning
        }.sorted {
            ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999)
        }
    }

    private var expiredItems: [Grocery] {
        activeGroceries.filter { $0.expirationStatus == .expired }
    }

    private var freshItems: [Grocery] {
        activeGroceries.filter { $0.expirationStatus == .fresh }
    }

    private var recentlyAdded: [Grocery] {
        Array(activeGroceries.prefix(5))
    }

    private var categoryBreakdown: [(category: FoodCategory, count: Int)] {
        let grouped = Dictionary(grouping: activeGroceries) { $0.category }
        return grouped.map { (category: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private var storageBreakdown: [(location: StorageLocation, count: Int)] {
        let grouped = Dictionary(grouping: activeGroceries) { $0.storageLocation }
        return grouped.map { (location: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats cards
                    statsSection

                    // Expiring soon alert
                    if !expiringSoonItems.isEmpty {
                        expiringSoonSection
                    }

                    // Expired items alert
                    if !expiredItems.isEmpty {
                        expiredSection
                    }

                    // Storage breakdown
                    if !activeGroceries.isEmpty {
                        storageSection
                    }

                    // Category breakdown
                    if !categoryBreakdown.isEmpty {
                        categorySection
                    }

                    // Recently added
                    if !recentlyAdded.isEmpty {
                        recentlyAddedSection
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
#if os(iOS)
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
            .sheet(item: $selectedStorageLocation) { location in
                StorageDetailSheet(location: location)
            }
            .sheet(item: $selectedCategory) { category in
                CategoryDetailSheet(category: category, categoryColor: categoryColor(for: category))
            }
            .sheet(isPresented: $showingTotalItems) {
                TotalItemsSheet()
            }
            .sheet(isPresented: $showingExpiringSoon) {
                ExpiringSoonSheet()
            }
            .sheet(isPresented: $showingExpired) {
                ExpiredItemsSheet()
            }
            .sheet(isPresented: $showingConsumed) {
                ConsumedItemsSheet()
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            Button {
                showingTotalItems = true
            } label: {
                StatCard(
                    title: "Total Items",
                    value: "\(activeGroceries.count)",
                    icon: "refrigerator.fill",
                    color: .blue
                )
            }
            .buttonStyle(.plain)

            Button {
                showingExpiringSoon = true
            } label: {
                StatCard(
                    title: "Expiring Soon",
                    value: "\(expiringSoonItems.count)",
                    icon: "exclamationmark.triangle.fill",
                    color: expiringSoonItems.isEmpty ? .green : .orange
                )
            }
            .buttonStyle(.plain)

            Button {
                showingExpired = true
            } label: {
                StatCard(
                    title: "Expired",
                    value: "\(expiredItems.count)",
                    icon: "xmark.circle.fill",
                    color: expiredItems.isEmpty ? .green : .red
                )
            }
            .buttonStyle(.plain)

            Button {
                showingConsumed = true
            } label: {
                StatCard(
                    title: "Consumed",
                    value: "\(consumedGroceries.count)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Expiring Soon Section

    private var expiringSoonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Expiring Soon")
                    .font(.headline)
                Spacer()
                Text("\(expiringSoonItems.count) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(expiringSoonItems.prefix(5)) { grocery in
                    HStack(spacing: 12) {
                        Image(systemName: grocery.category.icon)
                            .foregroundStyle(.orange)
                            .frame(width: 24)

                        Text(grocery.name)
                            .lineLimit(1)

                        Spacer()

                        if let days = grocery.daysUntilExpiration {
                            Text(days == 0 ? "Today" : days == 1 ? "Tomorrow" : "\(days) days")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    grocery.expirationStatus == .critical
                                        ? Color.red.opacity(0.15)
                                        : Color.orange.opacity(0.15)
                                )
                                .foregroundStyle(
                                    grocery.expirationStatus == .critical ? .red : .orange
                                )
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)

                    if grocery.id != expiringSoonItems.prefix(5).last?.id {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Expired Section

    private var expiredSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Expired")
                    .font(.headline)
                Spacer()
                Text("\(expiredItems.count) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(expiredItems.prefix(3)) { grocery in
                    HStack(spacing: 12) {
                        Image(systemName: grocery.category.icon)
                            .foregroundStyle(.red)
                            .frame(width: 24)

                        Text(grocery.name)
                            .lineLimit(1)

                        Spacer()

                        if let days = grocery.daysUntilExpiration {
                            Text("\(abs(days))d ago")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)

                    if grocery.id != expiredItems.prefix(3).last?.id {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.red.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By Storage Location")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(storageBreakdown, id: \.location) { item in
                    Button {
                        selectedStorageLocation = item.location
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.location.icon)
                                .foregroundStyle(.tint)
                                .frame(width: 24)

                            Text(item.location.rawValue)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text("\(item.count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if item.location != storageBreakdown.last?.location {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By Category")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(categoryBreakdown.prefix(6), id: \.category) { item in
                    Button {
                        selectedCategory = item.category
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.category.icon)
                                .font(.title3)
                                .foregroundStyle(categoryColor(for: item.category))

                            Text(item.category.rawValue)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundStyle(.primary)

                            Text("\(item.count)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Recently Added Section

    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recently Added")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(recentlyAdded) { grocery in
                    HStack(spacing: 12) {
                        Image(systemName: grocery.category.icon)
                            .foregroundStyle(categoryColor(for: grocery.category))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(grocery.name)
                                .lineLimit(1)
                            Text(grocery.purchaseDate, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(grocery.quantityDisplayText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)

                    if grocery.id != recentlyAdded.last?.id {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Helpers

    private func categoryColor(for category: FoodCategory) -> Color {
        switch category {
        case .dairy: return .blue
        case .meat: return .red
        case .seafood: return .cyan
        case .produce: return .green
        case .bakery: return .orange
        case .frozen: return .indigo
        case .pantry: return .brown
        case .beverages: return .purple
        case .condiments: return .yellow
        case .snacks: return .pink
        case .other: return .gray
        }
    }
}

// MARK: - StatCard

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Storage Detail Sheet

struct StorageDetailSheet: View {
    let location: StorageLocation
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Grocery> { $0.consumedDate == nil },
        sort: \Grocery.purchaseDate,
        order: .reverse
    ) private var allGroceries: [Grocery]

    init(location: StorageLocation) {
        self.location = location
    }

    private var groceries: [Grocery] {
        allGroceries.filter { $0.storageLocation == location }
            .sorted { ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999) }
    }

    var body: some View {
        NavigationStack {
            List {
                if groceries.isEmpty {
                    ContentUnavailableView {
                        Label("No Items", systemImage: location.icon)
                    } description: {
                        Text("No groceries stored in \(location.rawValue.lowercased()).")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(groceries) { grocery in
                        HStack(spacing: 12) {
                            Image(systemName: grocery.category.icon)
                                .foregroundStyle(.tint)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(grocery.name)
                                    .lineLimit(1)
                                Text(grocery.quantityDisplayText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let days = grocery.daysUntilExpiration {
                                ExpirationBadge(days: days, status: grocery.expirationStatus)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(location.rawValue)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium, .large])
#else
        .frame(minWidth: 400, minHeight: 300)
#endif
    }
}

// MARK: - Category Detail Sheet

struct CategoryDetailSheet: View {
    let category: FoodCategory
    let categoryColor: Color
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Grocery> { $0.consumedDate == nil },
        sort: \Grocery.purchaseDate,
        order: .reverse
    ) private var allGroceries: [Grocery]

    init(category: FoodCategory, categoryColor: Color) {
        self.category = category
        self.categoryColor = categoryColor
    }

    private var groceries: [Grocery] {
        allGroceries.filter { $0.category == category }
            .sorted { ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999) }
    }

    var body: some View {
        NavigationStack {
            List {
                if groceries.isEmpty {
                    ContentUnavailableView {
                        Label("No Items", systemImage: category.icon)
                    } description: {
                        Text("No \(category.rawValue.lowercased()) items in your pantry.")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(groceries) { grocery in
                        HStack(spacing: 12) {
                            Image(systemName: grocery.storageLocation.icon)
                                .foregroundStyle(categoryColor)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(grocery.name)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Text(grocery.quantityDisplayText)
                                    Text("·")
                                    Text(grocery.storageLocation.rawValue)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let days = grocery.daysUntilExpiration {
                                ExpirationBadge(days: days, status: grocery.expirationStatus)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(category.rawValue)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium, .large])
#else
        .frame(minWidth: 400, minHeight: 300)
#endif
    }
}

// MARK: - Total Items Sheet

struct TotalItemsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Grocery> { $0.consumedDate == nil },
        sort: \Grocery.purchaseDate,
        order: .reverse
    ) private var groceries: [Grocery]

    var body: some View {
        NavigationStack {
            List {
                if groceries.isEmpty {
                    ContentUnavailableView {
                        Label("No Items", systemImage: "refrigerator")
                    } description: {
                        Text("Your pantry is empty. Add some groceries to get started.")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(groceries) { grocery in
                        GroceryItemRow(grocery: grocery)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("All Items (\(groceries.count))")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium, .large])
#else
        .frame(minWidth: 400, minHeight: 300)
#endif
    }
}

// MARK: - Expiring Soon Sheet

struct ExpiringSoonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Grocery> { $0.consumedDate == nil },
        sort: \Grocery.expirationDate
    ) private var allGroceries: [Grocery]

    private var expiringSoonGroceries: [Grocery] {
        allGroceries.filter {
            $0.expirationStatus == .critical || $0.expirationStatus == .warning
        }.sorted {
            ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if expiringSoonGroceries.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing Expiring Soon", systemImage: "checkmark.circle")
                    } description: {
                        Text("Great news! None of your items are expiring soon.")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(expiringSoonGroceries) { grocery in
                        GroceryItemRow(grocery: grocery)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Expiring Soon (\(expiringSoonGroceries.count))")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium, .large])
#else
        .frame(minWidth: 400, minHeight: 300)
#endif
    }
}

// MARK: - Expired Items Sheet

struct ExpiredItemsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Grocery> { $0.consumedDate == nil },
        sort: \Grocery.expirationDate
    ) private var allGroceries: [Grocery]

    private var expiredGroceries: [Grocery] {
        allGroceries.filter { $0.expirationStatus == .expired }
            .sorted { ($0.daysUntilExpiration ?? 0) < ($1.daysUntilExpiration ?? 0) }
    }

    var body: some View {
        NavigationStack {
            List {
                if expiredGroceries.isEmpty {
                    ContentUnavailableView {
                        Label("No Expired Items", systemImage: "checkmark.circle")
                    } description: {
                        Text("Great job! You don't have any expired items.")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(expiredGroceries) { grocery in
                        GroceryItemRow(grocery: grocery)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Expired (\(expiredGroceries.count))")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium, .large])
#else
        .frame(minWidth: 400, minHeight: 300)
#endif
    }
}

// MARK: - Consumed Items Sheet

struct ConsumedItemsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Grocery> { $0.consumedDate != nil },
        sort: \Grocery.consumedDate,
        order: .reverse
    ) private var consumedGroceries: [Grocery]

    var body: some View {
        NavigationStack {
            List {
                if consumedGroceries.isEmpty {
                    ContentUnavailableView {
                        Label("No Consumed Items", systemImage: "checkmark.circle")
                    } description: {
                        Text("Items you mark as consumed will appear here.")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(consumedGroceries) { grocery in
                        HStack(spacing: 12) {
                            Image(systemName: grocery.category.icon)
                                .foregroundStyle(.green)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(grocery.name)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Text(grocery.quantityDisplayText)
                                    Text("·")
                                    Text(grocery.storageLocation.rawValue)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let consumedDate = grocery.consumedDate {
                                Text(consumedDate, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Consumed (\(consumedGroceries.count))")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium, .large])
#else
        .frame(minWidth: 400, minHeight: 300)
#endif
    }
}

// MARK: - Grocery Item Row (Reusable)

struct GroceryItemRow: View {
    let grocery: Grocery

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: grocery.category.icon)
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(grocery.name)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(grocery.quantityDisplayText)
                    Text("·")
                    Text(grocery.storageLocation.rawValue)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let days = grocery.daysUntilExpiration {
                ExpirationBadge(days: days, status: grocery.expirationStatus)
            }
        }
    }
}

// MARK: - Expiration Badge

struct ExpirationBadge: View {
    let days: Int
    let status: ExpirationStatus

    var body: some View {
        Text(badgeText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }

    private var badgeText: String {
        switch days {
        case ..<0: return "\(abs(days))d ago"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "\(days) days"
        }
    }

    private var badgeColor: Color {
        switch status {
        case .expired: return .gray
        case .critical: return .red
        case .warning: return .orange
        case .fresh: return .green
        case .unknown: return .secondary
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Grocery.self, configurations: config)

    return HomeView()
        .modelContainer(container)
}

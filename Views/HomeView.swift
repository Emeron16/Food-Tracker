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

    // MARK: - Computed Properties

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
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "Total Items",
                value: "\(activeGroceries.count)",
                icon: "refrigerator.fill",
                color: .blue
            )
            StatCard(
                title: "Expiring Soon",
                value: "\(expiringSoonItems.count)",
                icon: "exclamationmark.triangle.fill",
                color: expiringSoonItems.isEmpty ? .green : .orange
            )
            StatCard(
                title: "Expired",
                value: "\(expiredItems.count)",
                icon: "xmark.circle.fill",
                color: expiredItems.isEmpty ? .green : .red
            )
            StatCard(
                title: "Consumed",
                value: "\(consumedGroceries.count)",
                icon: "checkmark.circle.fill",
                color: .green
            )
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
                    HStack(spacing: 12) {
                        Image(systemName: item.location.icon)
                            .foregroundStyle(.tint)
                            .frame(width: 24)

                        Text(item.location.rawValue)

                        Spacer()

                        Text("\(item.count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)

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
                    VStack(spacing: 6) {
                        Image(systemName: item.category.icon)
                            .font(.title3)
                            .foregroundStyle(categoryColor(for: item.category))

                        Text(item.category.rawValue)
                            .font(.caption)
                            .lineLimit(1)

                        Text("\(item.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Grocery.self, configurations: config)
    
    return HomeView()
        .modelContainer(container)
}

import SwiftUI
import SwiftData

/// Home dashboard showing expiring items, quick stats, and recipe suggestions
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<GroceryItemEntity> { !$0.isConsumed },
        sort: \GroceryItemEntity.purchaseDate,
        order: .reverse
    ) private var groceryEntities: [GroceryItemEntity]

    @State private var showingAddSheet = false

    private var groceries: [GroceryItem] {
        groceryEntities.map { $0.toDomainModel() }
    }

    private var expiringItems: [GroceryItem] {
        groceries
            .filter { $0.expirationStatus == .critical || $0.expirationStatus == .warning }
            .sorted { ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999) }
    }

    private var expiredItems: [GroceryItem] {
        groceries.filter { $0.expirationStatus == .expired }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Cards
                    statsSection

                    // Expiring Soon Alert
                    if !expiringItems.isEmpty {
                        expiringSoonSection
                    }

                    // Expired Items Warning
                    if !expiredItems.isEmpty {
                        expiredItemsSection
                    }

                    // Recipe Suggestion (Placeholder)
                    recipeSuggestionSection

                    // Quick Actions
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle("FreshTrack")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddGroceryView { item in
                    let entity = GroceryItemEntity.from(item)
                    modelContext.insert(entity)
                }
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
                value: "\(groceries.count)",
                icon: "refrigerator.fill",
                color: .blue
            )

            StatCard(
                title: "Expiring Soon",
                value: "\(expiringItems.count)",
                icon: "exclamationmark.triangle.fill",
                color: expiringItems.isEmpty ? .green : .orange
            )

            StatCard(
                title: "Expired",
                value: "\(expiredItems.count)",
                icon: "xmark.circle.fill",
                color: expiredItems.isEmpty ? .green : .red
            )

            StatCard(
                title: "Categories",
                value: "\(Set(groceries.map { $0.category }).count)",
                icon: "folder.fill",
                color: .purple
            )
        }
    }

    // MARK: - Expiring Soon Section

    private var expiringSoonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .foregroundStyle(.orange)
                Text("Expiring Soon")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    ExpiringSoonListView(items: expiringItems)
                } label: {
                    Text("See All")
                        .font(.subheadline)
                }
            }

            VStack(spacing: 8) {
                ForEach(expiringItems.prefix(3)) { item in
                    HStack {
                        Image(systemName: item.category.icon)
                            .foregroundStyle(statusColor(for: item))
                            .frame(width: 24)

                        Text(item.name)
                            .lineLimit(1)

                        Spacer()

                        if let days = item.daysUntilExpiration {
                            Text(days == 0 ? "Today" : "\(days) day\(days == 1 ? "" : "s")")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(statusColor(for: item))
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Expired Items Section

    private var expiredItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Expired Items")
                    .font(.headline)
                Spacer()
                Text("\(expiredItems.count) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Consider removing these items from your pantry")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(expiredItems.prefix(4)) { item in
                    VStack(spacing: 4) {
                        Image(systemName: item.category.icon)
                            .font(.title3)
                            .foregroundStyle(.gray)
                        Text(item.name)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Recipe Suggestion Section

    private var recipeSuggestionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("Recipe Suggestion")
                    .font(.headline)
                Spacer()
            }

            if expiringItems.isEmpty {
                Text("Add some groceries to get personalized recipe suggestions!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Based on your expiring items:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        ForEach(expiringItems.prefix(3)) { item in
                            Text(item.name)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.purple.opacity(0.15))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Suggested Recipe")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Coming soon with recipe integration!")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                    }
                    .padding()
                    .background(.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Scan Barcode",
                    icon: "barcode.viewfinder",
                    color: .blue
                ) {
                    // Will navigate to scanner
                }

                QuickActionButton(
                    title: "Add Item",
                    icon: "plus.circle.fill",
                    color: .green
                ) {
                    showingAddSheet = true
                }

                QuickActionButton(
                    title: "Find Recipe",
                    icon: "book.fill",
                    color: .orange
                ) {
                    // Will navigate to recipes
                }
            }
        }
    }

    // MARK: - Helpers

    private func statusColor(for item: GroceryItem) -> Color {
        switch item.expirationStatus {
        case .fresh: return .green
        case .warning: return .orange
        case .critical: return .red
        case .expired: return .gray
        case .unknown: return .secondary
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Expiring Soon List View

struct ExpiringSoonListView: View {
    let items: [GroceryItem]

    var body: some View {
        List {
            ForEach(items) { item in
                GroceryItemRow(item: item)
            }
        }
        .navigationTitle("Expiring Soon")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .modelContainer(DataContainer.preview)
}

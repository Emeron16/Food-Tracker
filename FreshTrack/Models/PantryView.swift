//
//  PantryView.swift
//  FreshTrack
//
//  Created by Prince Marcelle on 1/26/26.
//

import SwiftUI
import SwiftData

struct PantryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Grocery> { !$0.isConsumed },
        sort: \Grocery.purchaseDate,
        order: .reverse
    ) private var groceries: [Grocery]
    @State private var showingAddGrocery = false
    @State private var searchText = ""
    @State private var groceryToEdit: Grocery?

    private var filteredGroceries: [Grocery] {
        if searchText.isEmpty {
            return groceries
        }
        return groceries.filter {
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
                                .contextMenu {
                                    contextMenuItems(for: grocery)
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

                // All items
                Section {
                    ForEach(filteredGroceries) { grocery in
                        GroceryRowView(grocery: grocery)
                            .contextMenu {
                                contextMenuItems(for: grocery)
                            }
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
            // Remove notifications for this grocery
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
            // Remove notifications for consumed grocery
            ExpirationNotificationService.shared.removeNotifications(for: grocery)
        }
        notifyGroceriesChanged()
    }

    private func notifyGroceriesChanged() {
        NotificationCenter.default.post(name: .groceriesDidChange, object: nil)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for grocery: Grocery) -> some View {
        Button {
            groceryToEdit = grocery
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button {
            markConsumed(grocery)
        } label: {
            Label("Mark as Used", systemImage: "checkmark.circle")
        }

        Divider()

        Button(role: .destructive) {
            deleteGrocery(grocery)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Grocery.self, configurations: config)
    
    return PantryView()
        .modelContainer(container)
}

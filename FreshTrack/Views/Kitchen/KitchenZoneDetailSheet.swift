//
//  KitchenZoneDetailSheet.swift
//  FreshTrack
//

import SwiftUI
import SwiftData

struct KitchenZoneDetailSheet: View {
    let location: StorageLocation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Grocery> { !$0.isConsumed },
        sort: \Grocery.createdAt,
        order: .reverse
    ) private var allGroceries: [Grocery]
    @State private var groceryToEdit: Grocery?

    private var items: [Grocery] {
        allGroceries
            .filter { $0.storageLocation == location }
            .sorted { ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999) }
    }

    private var urgentItems: [Grocery] {
        items.filter { $0.expirationStatus == .critical || $0.expirationStatus == .expired }
    }

    private var normalItems: [Grocery] {
        items.filter { $0.expirationStatus != .critical && $0.expirationStatus != .expired }
    }

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing Here", systemImage: location.icon)
                    } description: {
                        Text("Add groceries stored in your \(location.rawValue.lowercased()) to see them here.")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    if !urgentItems.isEmpty {
                        Section {
                            ForEach(urgentItems) { grocery in
                                InteractiveGroceryRow(
                                    grocery: grocery,
                                    iconColor: grocery.expirationStatus == .expired ? .gray : .red,
                                    onEdit: { groceryToEdit = $0 },
                                    onDelete: { deleteGrocery($0, context: modelContext) },
                                    onConsume: { markConsumed($0) }
                                )
                            }
                        } header: {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text("Needs Attention")
                            }
                        }
                    }

                    if !normalItems.isEmpty {
                        Section("All Items") {
                            ForEach(normalItems) { grocery in
                                InteractiveGroceryRow(
                                    grocery: grocery,
                                    iconColor: .accentColor,
                                    onEdit: { groceryToEdit = $0 },
                                    onDelete: { deleteGrocery($0, context: modelContext) },
                                    onConsume: { markConsumed($0) }
                                )
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("\(location.rawValue) (\(items.count))")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $groceryToEdit) { grocery in
                EditGroceryView(grocery: grocery)
            }
        }
#if os(iOS)
        .presentationDetents([.medium, .large])
#else
        .frame(minWidth: 400, minHeight: 300)
#endif
    }

    private func deleteGrocery(_ grocery: Grocery, context: ModelContext) {
        withAnimation {
            ExpirationNotificationService.shared.removeNotifications(for: grocery)
            context.delete(grocery)
        }
        NotificationCenter.default.post(name: .groceriesDidChange, object: nil)
    }

    private func markConsumed(_ grocery: Grocery) {
        withAnimation {
            grocery.isConsumed = true
            grocery.consumedDate = Date()
            grocery.updatedAt = Date()
            ExpirationNotificationService.shared.removeNotifications(for: grocery)
        }
        NotificationCenter.default.post(name: .groceriesDidChange, object: nil)
    }
}

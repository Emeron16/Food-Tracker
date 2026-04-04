//
//  ReceiptReviewView.swift
//  FreshTrack
//
//  Review parsed receipt items before adding them to the pantry.
//

import SwiftUI
import SwiftData

extension Int: @retroactive Identifiable { public var id: Int { self } }

struct ReceiptReviewView: View {
    @ObservedObject var service: ReceiptScannerService
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var searchingItemIndex: Int? = nil

    private var selectedItems: [ReceiptLineItem] {
        service.editableItems.filter { $0.isSelected }
    }

    private var readyCount: Int {
        selectedItems.filter { $0.isReady }.count
    }

    private var pendingCount: Int {
        selectedItems.filter { !$0.isReady }.count
    }

    private var canAdd: Bool {
        readyCount > 0 && pendingCount == 0
    }

    var body: some View {
        Group {
            if service.editableItems.isEmpty {
                ContentUnavailableView {
                    Label("No Items Found", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("No grocery items could be detected. Try a clearer, well-lit photo of your receipt.")
                }
            } else {
                VStack(spacing: 0) {
                    List {
                        Section {
                            ForEach(service.editableItems.indices, id: \.self) { i in
                                ReceiptLineItemRow(item: $service.editableItems[i]) {
                                    searchingItemIndex = i
                                }
                            }
                        } header: {
                            HStack {
                                Text("Found \(service.editableItems.count) item\(service.editableItems.count == 1 ? "" : "s")")
                                Spacer()
                                Button(selectedItems.count == service.editableItems.count ? "Deselect All" : "Select All") {
                                    let allSelected = selectedItems.count == service.editableItems.count
                                    for i in service.editableItems.indices {
                                        service.editableItems[i].isSelected = !allSelected
                                    }
                                }
                                .font(.caption)
                            }
                        } footer: {
                            Text("Tap any item to search and confirm it in Open Food Facts.")
                                .font(.caption)
                        }
                    }
                    .listStyle(.insetGrouped)

                    // Add button
                    VStack(spacing: 0) {
                        Divider()
                        VStack(spacing: 6) {
                            if pendingCount > 0 {
                                Text("\(pendingCount) item\(pendingCount == 1 ? "" : "s") need confirmation — tap to search")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            Button {
                                service.addGroceries(context: modelContext)
                                onDone()
                            } label: {
                                Text(buttonLabel)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(!canAdd)
                        }
                        .padding()
                    }
                    .background(.bar)
                }
            }
        }
        .navigationTitle("Review Items")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $searchingItemIndex) { i in
            if i < service.editableItems.count {
                ReceiptItemSearchSheet(item: $service.editableItems[i])
            }
        }
    }

    private var buttonLabel: String {
        if pendingCount > 0 { return "Confirm Items First" }
        if readyCount == 0 { return "No Items Selected" }
        return "Add \(readyCount) Item\(readyCount == 1 ? "" : "s") to Pantry"
    }
}

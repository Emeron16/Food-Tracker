//
//  ReceiptItemSearchSheet.swift
//  FreshTrack
//
//  Search Open Food Facts and confirm a receipt line item before adding to pantry.
//

import SwiftUI

struct ReceiptItemSearchSheet: View {
    @Binding var item: ReceiptLineItem
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String
    @State private var results: [(name: String, brand: String?)] = []
    @State private var isSearching = false
    @State private var hasSearched = false

    init(item: Binding<ReceiptLineItem>) {
        _item = item
        _searchText = State(initialValue: item.wrappedValue.resolvedName)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Product name", text: $searchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)
                        .onSubmit { performSearch() }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            results = []
                            hasSearched = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Button(action: performSearch) {
                    if isSearching {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white).scaleEffect(0.8)
                            Text("Searching…")
                        }
                    } else {
                        Text("Search")
                    }
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(searchText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.blue.opacity(0.4) : Color.blue)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 12)
                .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)

                Divider()

                if isSearching {
                    Spacer()
                    ProgressView("Searching…")
                    Spacer()
                } else if hasSearched && results.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No results found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try a shorter or simpler product name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Add Anyway") {
                            item.matchStatus = .confirmed
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                    }
                    .padding()
                    Spacer()
                } else if !results.isEmpty {
                    List(Array(results.enumerated()), id: \.offset) { _, result in
                        Button {
                            selectResult(result)
                        } label: {
                            OFFResultRow(name: result.name, brand: result.brand)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                } else {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("Search for a product")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Edit the name above and tap Search to find a match")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                }

                // "Add without match" footer
                if item.matchStatus == .unmatched || item.matchStatus == .pending {
                    Divider()
                    Button {
                        item.matchStatus = .confirmed
                        dismiss()
                    } label: {
                        Text("Add Without Match")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Find Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        hasSearched = false
        Task {
            results = await BarcodeAPIService.shared.searchProducts(query: query)
            isSearching = false
            hasSearched = true
        }
    }

    private func selectResult(_ result: (name: String, brand: String?)) {
        item.resolvedName = result.name
        item.matchedOFFName = result.name
        item.matchStatus = .matched
        dismiss()
    }
}

// MARK: - Result Row

private struct OFFResultRow: View {
    let name: String
    let brand: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "storefront")
                .frame(width: 44, height: 44)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if let brand, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle")
                .foregroundColor(.blue)
                .font(.title3)
        }
        .padding(.vertical, 4)
    }
}

//
//  ReceiptLineItemRow.swift
//  FreshTrack
//
//  A single editable row in the receipt review list. Tap the row to search OFF.
//

import SwiftUI

struct ReceiptLineItemRow: View {
    @Binding var item: ReceiptLineItem
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox — has its own tap; does NOT propagate to the row button
            Button {
                item.isSelected.toggle()
            } label: {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isSelected ? .accentColor : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            // Rest of row is a button that opens the search sheet
            Button {
                onTap?()
            } label: {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.resolvedName)
                            .font(.body)
                            .foregroundColor(item.isSelected ? .primary : .secondary)
                            .strikethrough(!item.isSelected)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            matchBadge

                            HStack(spacing: 4) {
                                Image(systemName: item.category.icon)
                                    .font(.caption)
                                Text(item.category.rawValue)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.secondarySystemFill), in: Capsule())
                            .foregroundColor(.secondary)

                            HStack(spacing: 4) {
                                Image(systemName: item.storageLocation.icon)
                                    .font(.caption)
                                Text(item.storageLocation.rawValue)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.secondarySystemFill), in: Capsule())
                            .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .padding(.top, 4)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .opacity(item.isSelected ? 1 : 0.5)
    }

    @ViewBuilder
    private var matchBadge: some View {
        switch item.matchStatus {
        case .pending:
            EmptyView()
        case .searching:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.55)
                Text("Checking")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        case .matched:
            Label("Verified", systemImage: "checkmark.seal.fill")
                .font(.caption2)
                .foregroundColor(.green)
        case .unmatched:
            Label("Tap to confirm", systemImage: "questionmark.circle")
                .font(.caption2)
                .foregroundColor(.orange)
        case .confirmed:
            Label("Confirmed", systemImage: "checkmark.circle")
                .font(.caption2)
                .foregroundColor(.blue)
        }
    }
}

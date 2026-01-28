//
//  GroceryRowView.swift
//  FreshTrack
//
//  Created by Prince Marcelle on 1/26/26.
//

import SwiftUI

struct GroceryRowView: View {
    let grocery: Grocery

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            categoryIcon

            // Item details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(grocery.name)
                        .font(.headline)
                        .lineLimit(1)

                    if let confidence = grocery.confidenceScore {
                        mlBadge(confidence: confidence)
                    }
                }

                HStack(spacing: 8) {
                    Text(grocery.quantityDisplayText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Label(grocery.storageLocation.rawValue, systemImage: grocery.storageLocation.icon)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Expiration status
            expirationBadge
        }
        .padding(.vertical, 4)
    }

    // MARK: - Category Icon

    private var categoryIcon: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.15))
                .frame(width: 44, height: 44)

            Image(systemName: grocery.category.icon)
                .font(.system(size: 20))
                .foregroundStyle(categoryColor)
        }
    }

    private var categoryColor: Color {
        switch grocery.category {
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

    // MARK: - ML Badge

    private func mlBadge(confidence: Double) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "brain")
                .font(.caption2)
            Text("\(Int(confidence * 100))%")
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.purple.opacity(0.15))
        .foregroundStyle(.purple)
        .clipShape(Capsule())
    }

    // MARK: - Expiration Badge

    private var expirationBadge: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(grocery.expirationStatus.label)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())

            if let days = grocery.daysUntilExpiration {
                Text(expirationShortText(for: days))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusColor: Color {
        switch grocery.expirationStatus {
        case .fresh: return .green
        case .warning: return .orange
        case .critical: return .red
        case .expired: return .gray
        case .unknown: return .secondary
        }
    }

    private func expirationShortText(for days: Int) -> String {
        switch days {
        case ..<0: return "\(abs(days))d ago"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "\(days) days"
        }
    }
}

#Preview {
    let sampleGrocery = Grocery(
        name: "Bananas",
        category: .produce,
        storageLocation: .counter,
        quantity: 6,
        unit: .piece,
        purchaseDate: Date(),
        expirationDate: Date().addingTimeInterval(3 * 24 * 60 * 60)
    )

    return GroceryRowView(grocery: sampleGrocery)
        .padding()
}

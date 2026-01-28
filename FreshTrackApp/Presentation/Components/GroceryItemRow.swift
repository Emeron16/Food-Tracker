import SwiftUI

/// A reusable row component for displaying grocery items in lists
struct GroceryItemRow: View {
    let item: GroceryItem
    var onConsume: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            categoryIcon

            // Item details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(1)

                    if let confidence = item.confidenceScore {
                        mlBadge(confidence: confidence)
                    }
                }

                HStack(spacing: 8) {
                    Text(item.quantityDisplayText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Label(item.storageLocation.rawValue, systemImage: item.storageLocation.icon)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Expiration status
            expirationBadge
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if let onConsume {
                Button {
                    onConsume()
                } label: {
                    Label("Used", systemImage: "checkmark.circle")
                }
                .tint(.green)
            }
        }
    }

    // MARK: - Subviews

    private var categoryIcon: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.15))
                .frame(width: 44, height: 44)

            Image(systemName: item.category.icon)
                .font(.system(size: 20))
                .foregroundStyle(categoryColor)
        }
    }

    private var categoryColor: Color {
        switch item.category {
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

    private var expirationBadge: some View {
        VStack(alignment: .trailing, spacing: 2) {
            statusBadge

            if let days = item.daysUntilExpiration {
                Text(expirationText(for: days))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusBadge: some View {
        Text(item.expirationStatus.label)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
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

    private func expirationText(for days: Int) -> String {
        switch days {
        case ..<0: return "\(abs(days))d ago"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "\(days) days"
        }
    }
}

// MARK: - Compact Variant

struct GroceryItemCompactRow: View {
    let item: GroceryItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.category.icon)
                .font(.system(size: 16))
                .foregroundStyle(statusColor)
                .frame(width: 24)

            Text(item.name)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            if let days = item.daysUntilExpiration {
                Text(days == 0 ? "Today" : "\(days)d")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.vertical, 6)
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

// MARK: - Previews

#Preview("Standard Row") {
    List {
        ForEach(GroceryItem.sampleItems) { item in
            GroceryItemRow(
                item: item,
                onConsume: { print("Consumed: \(item.name)") },
                onDelete: { print("Deleted: \(item.name)") }
            )
        }
    }
}

#Preview("Compact Row") {
    List {
        ForEach(GroceryItem.sampleItems) { item in
            GroceryItemCompactRow(item: item)
        }
    }
}

//
//  ReceiptLineItem.swift
//  FreshTrack
//
//  A parsed receipt line item ready for review before adding to the pantry.
//

import Foundation

enum ReceiptMatchStatus {
    case pending        // Not yet searched
    case searching      // OFF API call in progress
    case matched        // Found in OFF, name confirmed
    case unmatched      // Not found in OFF — user must confirm manually
    case confirmed      // User manually confirmed unmatched item
}

struct ReceiptLineItem: Identifiable {
    let id: String
    let rawDescription: String      // Raw OCR text from the receipt
    var resolvedName: String        // User-editable name for the grocery
    var quantity: Double
    var category: FoodCategory
    var storageLocation: StorageLocation
    var isSelected: Bool            // Whether to add this item to the pantry
    var matchStatus: ReceiptMatchStatus = .pending
    var matchedOFFName: String?     // Canonical name from Open Food Facts

    /// True when the item is ready to be added (matched by OFF or manually confirmed)
    var isReady: Bool {
        switch matchStatus {
        case .matched, .confirmed: return true
        default: return false
        }
    }
}

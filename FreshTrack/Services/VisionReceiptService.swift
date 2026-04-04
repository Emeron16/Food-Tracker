//
//  VisionReceiptService.swift
//  FreshTrack
//
//  Receipt OCR using Apple Vision framework — no API key required, works offline.
//

import Foundation
import UIKit
import Vision

class VisionReceiptService {
    static let shared = VisionReceiptService()

    private init() {
        print("🧾 VisionReceiptService initialized (Apple Vision, no API key needed)")
    }

    // MARK: - Public API

    func processReceipt(image: UIImage) async throws -> ReceiptPrediction {
        let normalizedImage = image.normalized()

        let observations = try await recognizeText(from: normalizedImage)

        guard !observations.isEmpty else {
            throw ReceiptOCRError.invalidResponse
        }

        // Vision bounding box origin is bottom-left, sort descending minY = top-to-bottom
        let sorted = observations.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        let lines: [String] = sorted.compactMap { $0.topCandidates(1).first?.string }

        guard !lines.isEmpty else {
            throw ReceiptOCRError.invalidResponse
        }

        print("🔍 Vision OCR extracted \(lines.count) text lines:")
        lines.enumerated().forEach { print("  [\($0.offset)] \($0.element)") }

        let lineItems = parseLineItems(from: sorted)
        let merchantName = extractMerchantName(from: lines)
        let total = extractTotal(from: lines)
        let tax = extractTax(from: lines)
        let dateString = extractDate(from: lines)
        let address = extractAddress(from: lines)

        print("📝 Parsed \(lineItems.count) line items")
        print("🏪 Merchant: \(merchantName ?? "Unknown")")
        print("💰 Total: \(total.map { "$\(String(format: "%.2f", $0))" } ?? "Unknown")")

        return ReceiptPrediction(
            supplier_name: merchantName.map { ReceiptField(value: $0) },
            supplier_address: address.map { ReceiptField(value: $0) },
            date: dateString.map { ReceiptField(value: $0) },
            time: nil,
            total_amount: total.map { ReceiptAmountField(value: $0) },
            total_tax: tax.map { ReceiptAmountField(value: $0) },
            line_items: lineItems.isEmpty ? nil : lineItems
        )
    }

    // MARK: - Vision Text Recognition

    private func recognizeText(from image: UIImage) async throws -> [VNRecognizedTextObservation] {
        guard let cgImage = image.cgImage else {
            throw ReceiptOCRError.imageCompressionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                continuation.resume(returning: observations)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Line Item Parsing

    /// Lines that are definitely not product items
    private let skipPatterns: [NSRegularExpression] = [
        // Totals, tax, subtotals — with or without leading asterisks/symbols
        try! NSRegularExpression(pattern: #"(?i)[\*\s]*(subtotal|sub-total|total|no\s+tax|tax|gst|hst|pst|vat|change|balance)\b"#),
        // Tax lines like "NY 8.875% Tax" or "CA 9% Tax"
        try! NSRegularExpression(pattern: #"(?i)\b\d+\.?\d*\s*%\s*(tax|gst|hst|pst|vat)\b"#),
        // Deposit lines
        try! NSRegularExpression(pattern: #"(?i)^\s*deposit\b"#),
        try! NSRegularExpression(pattern: #"(?i)\b(cash|card|visa|mastercard|amex|discover|debit|credit|payment|paid|approved|network\s+charge|charge)\b"#),
        try! NSRegularExpression(pattern: #"(?i)\b(thank|thanks|cashier|operator|register|terminal|loyalty|reward|points|member|survey|return|policy|refund|when\s+you|will\s+not|promotional|original\s+order)\b"#),
        try! NSRegularExpression(pattern: #"(?i)(www\.|https?://|\.com|\.net|\.org|@)"#),
        try! NSRegularExpression(pattern: #"(?i)(tel|phone|ph|fax)[\s:]*\d"#),
        try! NSRegularExpression(pattern: #"\b\d{3}[-.\s]\d{3}[-.\s]\d{4}\b"#),
        try! NSRegularExpression(pattern: #"(?i)\b(str|reg|trn|ref|auth|appr|seq|tran|inv|acct|rec|aid|auth\s+code)[\s#:]*\d*"#),
        try! NSRegularExpression(pattern: #"^\*?\d{4,}[A-Z]?$"#),
        try! NSRegularExpression(pattern: #"^[A-Z]{2,4}:\s"#),
        try! NSRegularExpression(pattern: #"\b\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}\b"#),
        try! NSRegularExpression(pattern: #"\b\d{1,2}:\d{2}(:\d{2})?\s*(AM|PM)?\b"#),
        try! NSRegularExpression(pattern: #"^\d{1,3}\s+[@0oO]\s+\$?\d"#),
        try! NSRegularExpression(pattern: #"(?i)^\d{1,3}\s+[@0oO]\s+\$?\d.*\b(ea|each|lb|oz|pk)\s*$"#),
        try! NSRegularExpression(pattern: #"(?i)^\s*(grocery|produce|bakery|deli|dairy|frozen|beverage|household|personal|nf|wic)\s*[\(]?\s*$"#),
        try! NSRegularExpression(pattern: #"(?i)^[A-Za-z][A-Za-z\s'1]+[,\.\s]\s*(New York|California|Texas|Florida|Illinois|Pennsylvania|Ohio|Georgia|Michigan|New Jersey|Washington|[A-Z]{2}\s*\d{0,5})\b"#),
        try! NSRegularExpression(pattern: #"\b\d{5}(-\d{4})?\b"#),
        try! NSRegularExpression(pattern: #"^[A-Za-z0-9][A-Za-z0-9\s]+,\s*$"#),
        try! NSRegularExpression(pattern: #"^\d{5}(-\d{4})?$"#),
        try! NSRegularExpression(pattern: #"(?i)\b(items?\s*(sold)?|savings?|you\s+saved|sale|coupon|discount)\b"#),
        try! NSRegularExpression(pattern: #"(?i)^\d+%\s+of\b"#),
        try! NSRegularExpression(pattern: #"(?i)\d[\d\.]*\s*(lb|[Ii]b|oz|kg|g|ea|each|/lb|/oz)\b"#),
        try! NSRegularExpression(pattern: #"(?i)^\d[\d\.]*\s*[Ii]b\b"#),
    ]

    private func shouldSkip(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..., in: line)
        for (idx, pattern) in skipPatterns.enumerated() {
            if pattern.firstMatch(in: line, range: range) != nil {
                print("  🚫 skip[\(idx)] matched: '\(line)'")
                return true
            }
        }
        return false
    }

    private func parseLineItems(from observations: [VNRecognizedTextObservation]) -> [LineItemPrediction] {
        let priceRegex = try! NSRegularExpression(pattern: #"\$?\s*(\d{1,3}(?:,\d{3})*\.\d{2})\s*[A-Z]?\s*\d?\s*$"#)
        let priceOnlyRegex = try! NSRegularExpression(pattern: #"^\s*\$?\s*(\d{1,3}(?:,\d{3})*\.\d{2})\s*[A-Z]?\s*\d?\s*$"#)

        struct ParsedLine {
            let text: String
            let price: Double?
            let isPriceOnly: Bool
        }

        let parsed: [ParsedLine] = observations.compactMap { obs in
            guard let text = obs.topCandidates(1).first?.string else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }

            let fullRange = NSRange(trimmed.startIndex..., in: trimmed)
            let isPriceOnly = priceOnlyRegex.firstMatch(in: trimmed, range: fullRange) != nil
            let price = extractPriceValue(from: trimmed, using: priceRegex)
            return ParsedLine(text: trimmed, price: price, isPriceOnly: isPriceOnly)
        }

        var results: [LineItemPrediction] = []
        var claimedIndices = Set<Int>()
        var i = 0

        print("🔎 Parsing \(parsed.count) lines:")
        parsed.enumerated().forEach { idx, p in
            let priceStr = p.price.map { String(format: "%.2f", $0) } ?? "nil"
            print("  [\(idx)] text='\(p.text)' price=\(priceStr) isPriceOnly=\(p.isPriceOnly) skip=\(shouldSkip(p.text))")
        }

        while i < parsed.count {
            let current = parsed[i]

            if shouldSkip(current.text) {
                print("⏭️ [\(i)] SKIP: '\(current.text)'")
                i += 1
                continue
            }

            // Pattern A: Line contains both description and price
            if let price = current.price, !current.isPriceOnly {
                let description = stripPriceFromEnd(from: current.text, using: priceRegex)
                    .trimmingCharacters(in: .whitespaces)
                if isValidDescription(description) {
                    print("✅ [\(i)] Pattern A: '\(description)' @ $\(price)")
                    results.append(LineItemPrediction(
                        description: description,
                        quantity: 1.0,
                        total_amount: price,
                        unit_price: price
                    ))
                    claimedIndices.insert(i)
                    i += 1
                    continue
                }
            }

            // Pattern B: Description line, then price-only line within 3 lines
            if isValidDescription(current.text) && !current.isPriceOnly {
                var found = false
                var lookahead = i + 1

                if lookahead < parsed.count {
                    let next = parsed[lookahead]
                    if shouldSkip(next.text), let qtyPrice = extractQuantityPrice(from: next.text) {
                        let totalPrice = qtyPrice.unitPrice * Double(qtyPrice.quantity)
                        print("✅ [\(i)] Pattern B-qty: '\(current.text)' @ $\(qtyPrice.unitPrice) x\(qtyPrice.quantity)")
                        results.append(LineItemPrediction(
                            description: current.text.trimmingCharacters(in: .whitespaces),
                            quantity: Double(qtyPrice.quantity),
                            total_amount: totalPrice,
                            unit_price: qtyPrice.unitPrice
                        ))
                        claimedIndices.insert(i)
                        claimedIndices.insert(lookahead)
                        i = lookahead + 1
                        found = true
                    }
                }

                while !found && lookahead < parsed.count && lookahead <= i + 3 {
                    let candidate = parsed[lookahead]
                    if candidate.isPriceOnly, let price = candidate.price, !shouldSkip(candidate.text) {
                        print("✅ [\(i)] Pattern B: '\(current.text)' @ $\(price) (price at [\(lookahead)])")
                        results.append(LineItemPrediction(
                            description: current.text.trimmingCharacters(in: .whitespaces),
                            quantity: 1.0,
                            total_amount: price,
                            unit_price: price
                        ))
                        claimedIndices.insert(i)
                        claimedIndices.insert(lookahead)
                        i = lookahead + 1
                        found = true
                        break
                    }
                    let isInterveningCode = candidate.text.trimmingCharacters(in: .whitespaces).count <= 3
                        || shouldSkip(candidate.text)
                    if isInterveningCode {
                        lookahead += 1
                    } else {
                        break
                    }
                }
                if found { continue }
                print("❌ [\(i)] Pattern B miss for: '\(current.text)'")
            }

            // Pattern C: Price-only line followed by description
            if current.isPriceOnly, let price = current.price, !shouldSkip(current.text) {
                var lookahead = i + 1
                var foundC = false
                while lookahead < parsed.count && lookahead <= i + 2 {
                    let candidate = parsed[lookahead]
                    let alreadyClaimed = claimedIndices.contains(lookahead)
                    if isValidDescription(candidate.text) && !candidate.isPriceOnly && !shouldSkip(candidate.text) && !alreadyClaimed {
                        print("✅ [\(i)] Pattern C: '\(candidate.text)' @ $\(price) (desc at [\(lookahead)])")
                        results.append(LineItemPrediction(
                            description: candidate.text.trimmingCharacters(in: .whitespaces),
                            quantity: 1.0,
                            total_amount: price,
                            unit_price: price
                        ))
                        claimedIndices.insert(i)
                        claimedIndices.insert(lookahead)
                        i = lookahead + 1
                        foundC = true
                        break
                    }
                    if candidate.text.trimmingCharacters(in: .whitespaces).count <= 3 && !isValidDescription(candidate.text) {
                        lookahead += 1
                    } else {
                        break
                    }
                }
                if foundC { continue }
                print("❌ [\(i)] Pattern C miss for price $\(price)")
            }

            print("⏩ [\(i)] No pattern matched: '\(current.text)'")
            i += 1
        }

        return results
    }

    private func extractQuantityPrice(from text: String) -> (quantity: Int, unitPrice: Double)? {
        let pattern = #"^(\d{1,3})\s*[@x]\s*\$?\s*(\d{1,3}(?:\.\d{2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges == 3,
              let qtyRange = Range(match.range(at: 1), in: text),
              let priceRange = Range(match.range(at: 2), in: text),
              let qty = Int(text[qtyRange]),
              let price = Double(text[priceRange]) else { return nil }
        return (qty, price)
    }

    private func isValidDescription(_ text: String) -> Bool {
        guard text.count >= 3 else { return false }
        guard !text.allSatisfy({ $0.isNumber || $0 == "," || $0 == "." || $0 == "-" }) else { return false }
        guard text.contains(where: { $0.isLetter }) else { return false }
        return true
    }

    // MARK: - Merchant Name Extraction

    private let knownStores: [String: String] = [
        "target": "Target",
        "walmart": "Walmart",
        "costco": "Costco",
        "kroger": "Kroger",
        "safeway": "Safeway",
        "whole foods": "Whole Foods",
        "trader joe": "Trader Joe's",
        "cvs": "CVS",
        "walgreens": "Walgreens",
        "rite aid": "Rite Aid",
        "publix": "Publix",
        "aldi": "ALDI",
        "lidl": "Lidl",
        "wegmans": "Wegmans",
        "meijer": "Meijer",
        "heb": "H-E-B",
        "food lion": "Food Lion",
        "stop & shop": "Stop & Shop",
        "giant": "Giant",
        "harris teeter": "Harris Teeter",
        "sprouts": "Sprouts",
        "dollar tree": "Dollar Tree",
        "dollar general": "Dollar General",
        "family dollar": "Family Dollar",
        "fine fare": "Fine Fare",
        "c-town": "C-Town",
        "c town": "C-Town",
        "key food": "Key Food",
        "shoprite": "ShopRite",
        "stop and shop": "Stop & Shop",
        "bjs": "BJ's",
        "bj's": "BJ's",
    ]

    private let merchantExcludeRegexes: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"^\d+\s+[A-Za-z]"#),
        try! NSRegularExpression(pattern: #"^\$?\d+\.\d{2}$"#),
        try! NSRegularExpression(pattern: #"^[A-Z0-9]{3,8}$"#),
        try! NSRegularExpression(pattern: #"(?i)(tel|phone|ph|fax)[\s:]*\d"#),
        try! NSRegularExpression(pattern: #"\(?\d{3}\)?[\s\-\.]\d{3}[\s\-\.]\d{4}"#),
        try! NSRegularExpression(pattern: #"\b\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}\b"#),
        try! NSRegularExpression(pattern: #"\b\d{5}\b"#),
        try! NSRegularExpression(pattern: #"(?i)^[A-Za-z][A-Za-z\s']+[,\s]\s*(New York|California|Texas|Florida|Illinois|Pennsylvania|Ohio|Georgia|Michigan|New Jersey|Washington|[A-Z]{2})\b"#),
        try! NSRegularExpression(pattern: #"(?i)\b(cashier|trx|tran|ref|register|terminal)\b"#),
    ]

    private func isMerchantCandidate(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3, trimmed.contains(where: { $0.isLetter }) else { return false }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        for regex in merchantExcludeRegexes {
            if regex.firstMatch(in: trimmed, range: range) != nil { return false }
        }
        return true
    }

    private func extractMerchantName(from lines: [String]) -> String? {
        let allText = lines.joined(separator: " ").lowercased()
        for (keyword, brandName) in knownStores {
            if allText.contains(keyword) { return brandName }
        }

        let topLines = Array(lines.prefix(max(6, lines.count / 3)))
        let storeHeaderRegex = try! NSRegularExpression(pattern: #".{4,}\s*[-–]\s*\d{3}"#)
        let streetWordRegex = try! NSRegularExpression(pattern: #"(?i)\b(hwy|highway|ave|avenue|blvd|boulevard|st|street|rd|road|dr|drive|ln|lane|pkwy|parkway|way|court|ct|pl|place)\b"#)

        for line in topLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            guard storeHeaderRegex.firstMatch(in: trimmed, range: range) != nil else { continue }
            let namePart = trimmed.components(separatedBy: " - ").first?
                .components(separatedBy: " – ").first?
                .trimmingCharacters(in: .whitespaces) ?? trimmed
            let nameRange = NSRange(namePart.startIndex..., in: namePart)
            let startsWithDigit = namePart.first?.isNumber == true
            let hasStreetWord = streetWordRegex.firstMatch(in: namePart, range: nameRange) != nil
            if namePart.count >= 4 && !startsWithDigit && !hasStreetWord { return namePart }
        }

        for line in topLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isMerchantCandidate(trimmed) { return trimmed }
        }
        return nil
    }

    // MARK: - Total / Tax / Date / Address

    private func extractTotal(from lines: [String]) -> Double? {
        let priceRegex = try! NSRegularExpression(pattern: #"\$?\s*(\d{1,3}(?:,\d{3})*\.\d{2})"#)
        var bestTotal: Double?
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
            guard lower.contains("total") && !lower.contains("subtotal") && !lower.contains("sub-total") else { continue }
            if let price = extractPriceValue(from: line, using: priceRegex) {
                if bestTotal == nil || price > bestTotal! { bestTotal = price }
            } else if i + 1 < lines.count, let price = extractPriceValue(from: lines[i + 1], using: priceRegex) {
                if bestTotal == nil || price > bestTotal! { bestTotal = price }
            }
        }
        return bestTotal
    }

    private func extractTax(from lines: [String]) -> Double? {
        let priceRegex = try! NSRegularExpression(pattern: #"\$?\s*(\d{1,3}(?:,\d{3})*\.\d{2})"#)
        for line in lines {
            let lower = line.lowercased()
            guard lower.contains("tax") || lower.contains("gst") || lower.contains("hst") || lower.contains("vat") else { continue }
            if let price = extractPriceValue(from: line, using: priceRegex) { return price }
        }
        return nil
    }

    private func extractDate(from lines: [String]) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = detector?.firstMatch(in: line, range: range), let date = match.date {
                if date <= Date().addingTimeInterval(30 * 86400) {
                    return formatter.string(from: date)
                }
            }
        }
        return nil
    }

    private func extractAddress(from lines: [String]) -> String? {
        let addressRegex = try! NSRegularExpression(pattern: #"^\d+\s+[A-Za-z]"#)
        let cityStateRegex = try! NSRegularExpression(
            pattern: #"(?i)^[A-Za-z][A-Za-z\s']+[,\s]\s*([A-Za-z]{2,}|[A-Z]{2})\b"#
        )
        let topLines = Array(lines.prefix(12))
        for (i, line) in topLines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            guard addressRegex.firstMatch(in: trimmed, range: range) != nil else { continue }
            var cityState: String? = nil
            for j in (i + 1)..<min(i + 4, topLines.count) {
                let next = topLines[j].trimmingCharacters(in: .whitespaces)
                let nextRange = NSRange(next.startIndex..., in: next)
                if cityStateRegex.firstMatch(in: next, range: nextRange) != nil {
                    let withoutZip = next.replacingOccurrences(
                        of: #"\s*\d{5}(-\d{4})?"#, with: "", options: .regularExpression
                    ).trimmingCharacters(in: .whitespaces)
                    cityState = withoutZip
                    break
                }
            }
            if let city = cityState { return "\(trimmed), \(city)" }
            return trimmed
        }
        return nil
    }

    // MARK: - Helpers

    private func extractPriceValue(from text: String, using regex: NSRegularExpression) -> Double? {
        let range = NSRange(text.startIndex..., in: text)
        var lastMatch: NSTextCheckingResult?
        regex.enumerateMatches(in: text, range: range) { match, _, _ in lastMatch = match }
        guard let match = lastMatch else { return nil }
        let valueRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
        guard let swiftRange = Range(valueRange, in: text) else { return nil }
        let priceString = String(text[swiftRange]).replacingOccurrences(of: ",", with: "")
        return Double(priceString)
    }

    private func stripPriceFromEnd(from text: String, using regex: NSRegularExpression) -> String {
        let range = NSRange(text.startIndex..., in: text)
        var lastMatchRange: NSRange?
        regex.enumerateMatches(in: text, range: range) { match, _, _ in lastMatchRange = match?.range }
        guard let matchRange = lastMatchRange,
              let swiftRange = Range(matchRange, in: text) else { return text }
        return String(text[text.startIndex..<swiftRange.lowerBound])
    }
}

// MARK: - UIImage Orientation Normalization

extension UIImage {
    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return normalized
    }
}

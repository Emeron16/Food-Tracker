//
//  BarcodeAPIService.swift
//  FreshTrack
//
//  Created by Prince Marcelle on 1/27/26.
//

import Foundation

#if os(iOS)

/// Service for looking up barcodes via the Open Food Facts API directly.
actor BarcodeAPIService {
    static let shared = BarcodeAPIService()

    private let baseURL = URL(string: "https://world.openfoodfacts.org/api/v2/product")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    /// Look up a barcode and return a ScannedProduct if found.
    nonisolated func lookupBarcode(_ barcode: String) async throws -> ScannedProduct? {
        let url = baseURL.appendingPathComponent(barcode)
        var request = URLRequest(url: url)
        request.setValue("FreshTrack iOS App - github.com/princemarcelle", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BarcodeError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 { return nil }
            throw BarcodeError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(OpenFoodFactsResponse.self, from: data)

        guard result.status == 1, let product = result.product, !product.productName.isEmpty else {
            return nil
        }

        return product.toScannedProduct(barcode: barcode)
    }
}

// MARK: - Open Food Facts DTOs

struct OpenFoodFactsResponse: Decodable, Sendable {
    let status: Int
    let product: OpenFoodFactsProduct?
}

struct OpenFoodFactsProduct: Decodable, Sendable {
    let productName: String
    let brands: String?
    let categories: String?
    let categoriesTags: [String]?
    let quantity: String?
    let imageFrontUrl: String?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case categories
        case categoriesTags = "categories_tags"
        case quantity
        case imageFrontUrl = "image_front_url"
    }

    func toScannedProduct(barcode: String) -> ScannedProduct {
        let category = mapCategory(from: categoriesTags ?? [])
        return ScannedProduct(
            barcode: barcode,
            name: productName,
            brand: brands,
            suggestedCategory: category,
            quantityString: quantity,
            imageURL: imageFrontUrl
        )
    }

    private func mapCategory(from tags: [String]) -> FoodCategory {
        let mapping: [(keyword: String, category: FoodCategory)] = [
            ("dairy", .dairy), ("milk", .dairy), ("cheese", .dairy),
            ("yogurt", .dairy), ("butter", .dairy),
            ("meat", .meat), ("beef", .meat), ("pork", .meat),
            ("chicken", .meat), ("turkey", .meat), ("sausage", .meat),
            ("fish", .seafood), ("seafood", .seafood), ("shrimp", .seafood),
            ("tuna", .seafood), ("salmon", .seafood),
            ("fruit", .produce), ("vegetable", .produce), ("salad", .produce),
            ("bread", .bakery), ("pastry", .bakery), ("cake", .bakery),
            ("frozen", .frozen), ("ice-cream", .frozen),
            ("beverage", .beverages), ("drink", .beverages), ("juice", .beverages),
            ("water", .beverages), ("soda", .beverages), ("coffee", .beverages),
            ("tea", .beverages),
            ("sauce", .condiments), ("condiment", .condiments),
            ("ketchup", .condiments), ("mustard", .condiments),
            ("snack", .snacks), ("chip", .snacks), ("cookie", .snacks),
            ("cracker", .snacks), ("candy", .snacks), ("chocolate", .snacks),
            ("cereal", .pantry), ("pasta", .pantry), ("rice", .pantry),
            ("canned", .pantry), ("flour", .pantry), ("sugar", .pantry),
            ("oil", .pantry),
        ]
        for tag in tags {
            let tagLower = tag.lowercased()
            for (keyword, category) in mapping {
                if tagLower.contains(keyword) {
                    return category
                }
            }
        }
        return .other
    }
}

// MARK: - Errors

enum BarcodeError: LocalizedError {
    case networkError
    case invalidBarcode
    case serverError(Int)
    case cameraUnavailable

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Unable to connect to server. Check your connection and try again."
        case .invalidBarcode:
            return "The scanned barcode format is not recognized."
        case .serverError(let code):
            return "Server error (code \(code)). Please try again."
        case .cameraUnavailable:
            return "Camera is not available on this device."
        }
    }
}

#endif

//
//  AmazonAffiliateService.swift
//  FreshTrack
//
//  Builds Amazon search URLs with an affiliate tag.
//  Sign up at affiliate-program.amazon.com, then replace
//  the affiliateTag value below with your Associates tag.
//

import Foundation

struct AmazonAffiliateService {

    /// Your Amazon Associates tracking tag.
    static let affiliateTag = "foodtracker07-20"

    /// Returns an Amazon search URL for the given query string, with the affiliate tag appended.
    /// Returns nil if the URL cannot be constructed (should not happen in practice).
    static func searchURL(for query: String) -> URL? {
        var components = URLComponents(string: "https://www.amazon.com/s")
        components?.queryItems = [
            URLQueryItem(name: "k",   value: query),
            URLQueryItem(name: "tag", value: affiliateTag)
        ]
        return components?.url
    }
}

//
//  TMDBResponses.swift
//  MovieTracker
//
//  Shared raw `Codable` shapes for the TMDB API; type-specific ones live in the extension files.
//

import Foundation

extension TMDBWrapper {
    /// The paging envelope every list/search endpoint returns.
    struct RootRaw<T: Codable>: Codable {
        var results: [T]
        var totalResults: Int
        var totalPages: Int

        private enum CodingKeys: String, CodingKey {
            case results
            case totalResults = "total_results"
            case totalPages = "total_pages"
        }
    }
}

//
//  TMDBWrapper.swift
//  MovieTracker
//
//  Created by Elliot Barer on 6/11/18.
//  Copyright © 2018 ebarer. All rights reserved.
//

import Foundation

/// A thin client for the TMDB API. Endpoints (and their raw→domain `translate`
/// helpers) live in `TMDBWrapper+Movies` and `TMDBWrapper+People`, and the raw
/// response types in `TMDBResponses`. This file holds the shared request/decode
/// plumbing, image helpers, and the result/error types.
class TMDBWrapper {
    private static let baseURL = "https://api.themoviedb.org"
    private static let imageBaseURL = "https://image.tmdb.org/t/p"
    private static let apiVersion = "/3"
    private static let apiKey = "da99299f02cd39e2736c97d08b459731"
    private static let regionCode = NSLocale.current.region?.identifier ?? "US"
    private static let languageCode = NSLocale.current.language.languageCode?.identifier ?? "en"

    /// Keywords identifying during/after credit extras (read by `MovieRaw`).
    static let bonusKeywords = ["during": 179431, "after": 179430]
}

// MARK: - Requests

extension TMDBWrapper {
    /// The locale/key query items sent with every request.
    private static var localeQueryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "with_original_language", value: languageCode),
            URLQueryItem(name: "language", value: "\(languageCode)-\(regionCode)"),
            URLQueryItem(name: "region", value: regionCode),
        ]
    }

    /// Performs a GET against the API, appending the shared query items (plus a
    /// certification country for movie endpoints), and returns the raw response.
    static func fetch(_ path: String, queryItems: [URLQueryItem] = [],
                      certified: Bool = false) async throws -> Data {
        var components = URLComponents(string: baseURL)!
        components.path = apiVersion + path
        components.queryItems = queryItems + localeQueryItems
            + (certified ? [URLQueryItem(name: "certification_country", value: regionCode)] : [])

        guard let url = components.url else {
            throw FetchError.noData("Couldn't build request URL.")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw FetchError.decode("Couldn't decode JSON data: \(error)")
        }
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            return DateFormatter.iso8601DAw.date(from: dateString)
                ?? DateFormatter.iso8601DTw.date(from: dateString)
                ?? Date()
        }
        return decoder
    }
}

// MARK: - Images

extension TMDBWrapper {
    /// A fully-qualified TMDB image URL for the given path and size.
    static func imageURL(path: String?, size: String) -> URL? {
        guard let path else { return nil }
        return URL(string: "\(imageBaseURL)/\(size)/\(path)")
    }

    /// Raw image data (e.g. for average-color extraction).
    static func imageData(from url: URL) async throws -> Data {
        try await URLSession.shared.data(from: url).0
    }
}

// MARK: - Results & errors

/// A page of results returned by a TMDB list/search endpoint.
struct PagedResult<Element> {
    let items: [Element]
    let totalResults: Int
    let totalPages: Int

    static var empty: PagedResult { PagedResult(items: [], totalResults: 0, totalPages: 1) }
}

enum FetchError: Error {
    case noData(String)
    case decode(String)
    case image(String)
}

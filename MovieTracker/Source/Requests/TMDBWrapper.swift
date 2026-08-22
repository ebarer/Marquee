//
//  TMDBWrapper.swift
//  MovieTracker
//
//  Created by Elliot Barer on 6/11/18.
//  Copyright © 2018 ebarer. All rights reserved.
//

import Foundation

class TMDBWrapper {
    private static let baseURL = "https://api.themoviedb.org"
    private static let imageBaseURL = "https://image.tmdb.org/t/p"
    private static let apiVersion = "/3"
    private static let apiKey = "da99299f02cd39e2736c97d08b459731"
    private static let regionCode = NSLocale.current.region?.identifier ?? "US"
    private static let languageCode = NSLocale.current.language.languageCode?.identifier ?? "en"

    static let bonusKeywords = ["during": 179431, "after": 179430]
}

// MARK: - Requests

extension TMDBWrapper {
    private static var localeQueryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "with_original_language", value: languageCode),
            URLQueryItem(name: "language", value: "\(languageCode)-\(regionCode)"),
            URLQueryItem(name: "region", value: regionCode),
        ]
    }

    static func fetch(_ path: String, queryItems: [URLQueryItem] = [],
                      certified: Bool = false) async throws -> Data {
        var components = URLComponents(string: baseURL)!
        components.path = apiVersion + path
        components.queryItems = queryItems + localeQueryItems
            + (certified ? [URLQueryItem(name: "certification_country", value: regionCode)] : [])

        guard let url = components.url else {
            throw FetchError.noData("Couldn't build request URL.")
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        // Unchecked, TMDB's JSON error body fails to decode and a 404 or 429 reads as malformed data.
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw FetchError.http(status: http.statusCode, path: path)
        }
        return data
    }

    static func dateParam(daysFromNow days: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return DateFormatter.iso8601DAw.string(from: date)
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
    static func imageURL(path: String?, size: String) -> URL? {
        guard let path else { return nil }
        return URL(string: "\(imageBaseURL)/\(size)/\(path)")
    }

    static func imageData(from url: URL) async throws -> Data {
        try await URLSession.shared.data(from: url).0
    }
}

// MARK: - Results & errors

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
    case http(status: Int, path: String)
}

extension Error {
    // A 404 means this title has no such resource and never will; retrying the plan is pointless.
    var isPermanentHTTPFailure: Bool {
        guard case .http(let status, _) = self as? FetchError ?? .noData("") else { return false }
        return (400...499).contains(status) && status != 429
    }
}

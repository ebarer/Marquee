//
//  TMDBWrapper+Async.swift
//  MovieTracker
//
//  Modern async/await entry points layered on top of the existing
//  completion-handler API, plus image URL/data helpers for SwiftUI.
//  The original completion-handler methods remain for callers that
//  have not yet been migrated.
//

import Foundation
import UIKit

// MARK: - Paged result

/// A page of results returned by a TMDB list/search endpoint.
struct PagedResult<Element> {
    let items: [Element]
    let totalResults: Int
    let totalPages: Int
}

// MARK: - Async API accessors

extension TMDBWrapper {
    static func getMovie(id: Int) async throws -> Movie {
        try await withCheckedThrowingContinuation { continuation in
            getMovie(id: id) { movie, error in
                continuation.resume(with: Self.result(movie, error))
            }
        }
    }

    static func moviesPopular(page: Int) async throws -> PagedResult<Movie> {
        try await withCheckedThrowingContinuation { continuation in
            getMoviesPopular(page: page) { movies, error, pagination in
                continuation.resume(with: Self.pagedResult(movies, error, pagination))
            }
        }
    }

    static func moviesNowPlaying(page: Int) async throws -> PagedResult<Movie> {
        try await withCheckedThrowingContinuation { continuation in
            getMoviesNowPlaying(page: page) { movies, error, pagination in
                continuation.resume(with: Self.pagedResult(movies, error, pagination))
            }
        }
    }

    static func moviesComingSoon(page: Int) async throws -> PagedResult<Movie> {
        try await withCheckedThrowingContinuation { continuation in
            getMoviesComingSoon(page: page) { movies, error, pagination in
                continuation.resume(with: Self.pagedResult(movies, error, pagination))
            }
        }
    }

    static func searchForMovies(query: String, page: Int = 1) async throws -> PagedResult<Movie> {
        try await withCheckedThrowingContinuation { continuation in
            searchForMovies(query: query, page: page) { movies, error, pagination in
                continuation.resume(with: Self.pagedResult(movies, error, pagination))
            }
        }
    }

    static func getPerson(id: Int) async throws -> Person {
        try await withCheckedThrowingContinuation { continuation in
            getPerson(id: id) { person, error in
                continuation.resume(with: Self.result(person, error))
            }
        }
    }

    static func searchForPeople(query: String, page: Int = 1) async throws -> PagedResult<Person> {
        try await withCheckedThrowingContinuation { continuation in
            searchForPeople(query: query, page: page) { people, error, pagination in
                continuation.resume(with: Self.pagedResult(people, error, pagination))
            }
        }
    }
}

// MARK: - Continuation helpers

private extension TMDBWrapper {
    /// Maps a `(value, error)` completion pair into a `Result` for a continuation.
    static func result<T>(_ value: T?, _ error: Error?) -> Result<T, Error> {
        if let value {
            return .success(value)
        }
        return .failure(error ?? FetchError.noData("Response contained no data."))
    }

    /// Maps a paged `(items, error, pagination)` completion into a `Result<PagedResult>`.
    static func pagedResult<T>(
        _ items: [T]?,
        _ error: Error?,
        _ pagination: (results: Int, pages: Int)?
    ) -> Result<PagedResult<T>, Error> {
        if let error {
            return .failure(error)
        }
        let paged = PagedResult(
            items: items ?? [],
            totalResults: pagination?.results ?? (items?.count ?? 0),
            totalPages: pagination?.pages ?? 1
        )
        return .success(paged)
    }
}

// MARK: - Image URLs & data

extension TMDBWrapper {
    static let publicImageBaseURL = "https://image.tmdb.org/t/p"

    /// Builds a fully-qualified TMDB image URL for the given path and size.
    static func imageURL(path: String?, size: String) -> URL? {
        guard let path else { return nil }
        return URL(string: "\(publicImageBaseURL)/\(size)/\(path)")
    }

    /// Downloads raw image data (e.g. for average-color extraction).
    static func imageData(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}

// MARK: - Model image URL helpers (for SwiftUI AsyncImage)

extension Movie {
    func posterURL(_ size: Movie.PosterSize = .w342) -> URL? {
        TMDBWrapper.imageURL(path: poster, size: size.rawValue)
    }

    func backgroundURL(_ size: Movie.BackgroundSize = .w1280) -> URL? {
        TMDBWrapper.imageURL(path: background, size: size.rawValue)
    }
}

extension Person {
    func profileURL(_ size: Person.ProfileSize = .w276) -> URL? {
        TMDBWrapper.imageURL(path: profilePicture, size: size.rawValue)
    }
}

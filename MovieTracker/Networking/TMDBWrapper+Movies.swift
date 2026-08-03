//
//  TMDBWrapper+Movies.swift
//  MovieTracker
//

import Foundation

extension TMDBWrapper {
    static func getMovie(id: Int) async throws -> Movie {
        let data = try await fetch(
            "/movie/\(id)",
            queryItems: [
                URLQueryItem(name: "with_release_type", value: "3|2"),
                URLQueryItem(name: "append_to_response", value: "videos,release_dates,credits,keywords"),
            ],
            certified: true
        )
        return translate(movie: try decode(MovieRaw.self, from: data))
    }

    static func getCollection(id: Int) async throws -> [Movie] {
        let data = try await fetch("/collection/\(id)", certified: true)
        let collection = try decode(CollectionRaw.self, from: data)
        // Oldest-to-newest so the franchise reads chronologically.
        return collection.parts.map(translate(movie:)).sorted {
            guard let a = $0.releaseDate else { return false }
            guard let b = $1.releaseDate else { return true }
            return a < b
        }
    }

    static func moviesNowPlaying(page: Int) async throws -> PagedResult<Movie> {
        try await moviePage("/movie/now_playing", page: page)
    }

    static func moviesPopular(page: Int) async throws -> PagedResult<Movie> {
        try await moviePage("/movie/popular", page: page)
    }

    static func moviesComingSoon(page: Int) async throws -> PagedResult<Movie> {
        try await moviePage("/movie/upcoming", page: page)
    }

    static func movieRecommendations(id: Int, page: Int = 1) async throws -> PagedResult<Movie> {
        try await moviePage("/movie/\(id)/recommendations", page: page)
    }

    static func searchForMovies(query: String, page: Int = 1) async throws -> PagedResult<Movie> {
        guard !query.isEmpty else { return .empty }
        return try await moviePage("/search/movie", page: page,
                                   queryItems: [URLQueryItem(name: "query", value: query)])
    }

    /// Shared fetch/decode for the paged movie list and search endpoints.
    private static func moviePage(_ path: String, page: Int,
                                  queryItems: [URLQueryItem] = []) async throws -> PagedResult<Movie> {
        guard page > 0 else {
            throw FetchError.decode("Invalid page number (index starts at 1).")
        }
        let data = try await fetch(path, queryItems: queryItems + [
            URLQueryItem(name: "page", value: String(page))
        ], certified: true)
        let root = try decode(RootRaw<MovieRaw>.self, from: data)
        return PagedResult(items: root.results.map(translate(movie:)),
                           totalResults: root.totalResults, totalPages: root.totalPages)
    }
}

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
                URLQueryItem(name: "append_to_response", value: "videos,release_dates,credits,keywords,watch/providers"),
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

    /// Region's streaming services, most popular first (backs the picker).
    static func watchProviders(region: String) async throws -> [WatchProvider] {
        let data = try await fetch("/watch/providers/movie",
                                   queryItems: [URLQueryItem(name: "watch_region", value: region)])
        let root = try decode(ProviderListRaw.self, from: data)
        return root.results
            .filter { $0.isAvailable(in: region) }
            .sorted { $0.priority(in: region) < $1.priority(in: region) }
            .map { WatchProvider(id: $0.providerId, name: $0.providerName, logoPath: $0.logoPath) }
    }

    /// A movie's cast in billing order. Used by search to surface actors by the
    /// character they played (e.g. "spiderman" → everyone credited as Spider-Man).
    static func movieCast(id: Int) async throws -> [Person] {
        let data = try await fetch("/movie/\(id)/credits")
        let team = try decode(MovieRaw.TeamRaw.self, from: data)
        return team.cast
            .sorted { $0.order < $1.order }
            .map { Person(id: $0.id, name: $0.name, role: $0.role, pic: $0.profilePicture, type: .Cast) }
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

    /// Maps a raw movie response onto the domain `Movie`.
    static func translate(movie mv: MovieRaw) -> Movie {
        var movie = Movie(id: mv.id, title: mv.title)

        if let overview = mv.overview, !overview.isEmpty {
            movie.overview = overview
        }

        movie.poster = mv.poster
        movie.background = mv.background
        movie.runtime = mv.runtime
        movie.rating = mv.rating
        movie.popularity = mv.popularity
        movie.voteCount = mv.voteCount
        movie.imdbID = mv.imdbID

        let releaseInfo = mv.certification()
        if let releaseDate = releaseInfo.releaseDate {
            movie.releaseDate = releaseDate
        } else if let releaseDateString = mv.releaseDateString {
            movie.releaseDate = releaseDateString.toDate(format: .iso8601DAw)
        }

        movie.certification = releaseInfo.certification
        movie.genres = mv.genres()
        movie.bonusCredits = Movie.Credits(mv.bonusCredits())
        movie.team = mv.team()
        movie.trailers = mv.trailers()
        movie.collection = mv.collection()
        movie.watchByRegion = mv.watchByRegion()

        return movie
    }
}

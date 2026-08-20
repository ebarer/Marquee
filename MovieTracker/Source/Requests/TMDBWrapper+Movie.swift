//
//  TMDBWrapper+Movie.swift
//  MovieTracker
//

import Foundation

extension TMDBWrapper {
    static func getMovie(id: Int) async throws -> Movie {
        let data = try await fetch(
            "/movie/\(id)",
            queryItems: [
                URLQueryItem(name: "with_release_type", value: "3|2"),
                URLQueryItem(name: "append_to_response", value: "videos,release_dates,credits,keywords,watch/providers,external_ids"),
            ],
            certified: true
        )
        var movie = translate(movie: try decode(MovieRaw.self, from: data))
        // The one response carrying every field, so the one place that can vouch for it.
        movie.isFullDetail = true
        return movie
    }

    static func movieRuntime(id: Int) async throws -> Int? {
        let data = try await fetch("/movie/\(id)")
        return try decode(MovieRaw.self, from: data).runtime
    }

    static func getCollection(id: Int) async throws -> [Movie] {
        let data = try await fetch("/collection/\(id)", certified: true)
        let collection = try decode(CollectionRaw.self, from: data)
        return collection.parts.map(translate(movie:)).sorted {
            guard let left = $0.releaseDate else { return false }
            guard let right = $1.releaseDate else { return true }
            return left < right
        }
    }

    // /search/* omits `belongs_to_collection`, so take base fields and credits in one call.
    static func movieSearchDetail(id: Int) async throws -> Movie {
        let data = try await fetch("/movie/\(id)",
                                   queryItems: [URLQueryItem(name: "append_to_response", value: "credits")])
        return translate(movie: try decode(MovieRaw.self, from: data))
    }

    static func moviesNowPlaying(page: Int) async throws -> PagedResult<Movie> {
        // Region release date catches a film that premiered abroad first. The primary-date floor then drops
        // anniversary re-releases, and the vote floor the one-screening long tail.
        try await discoverMovies(page: page, extra: [
            URLQueryItem(name: "with_release_type", value: "2|3"),
            URLQueryItem(name: "release_date.gte", value: dateParam(daysFromNow: -42)),
            URLQueryItem(name: "release_date.lte", value: dateParam(daysFromNow: 0)),
            URLQueryItem(name: "primary_release_date.gte", value: dateParam(daysFromNow: -365)),
            URLQueryItem(name: "vote_count.gte", value: "10"),
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
        ])
    }

    static func moviesPopular(page: Int) async throws -> PagedResult<Movie> {
        // `vote_count.gte` filters out thin duplicate records that ride a title's popularity without the
        // audience to back it; popularity alone can't tell them apart.
        try await discoverMovies(page: page, extra: [
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            URLQueryItem(name: "vote_count.gte", value: "100"),
        ])
    }

    static func moviesComingSoon(page: Int) async throws -> PagedResult<Movie> {
        // `primary_release_date` excludes re-releases of old films that a plain region filter would pull in.
        try await discoverMovies(page: page, extra: [
            URLQueryItem(name: "primary_release_date.gte", value: dateParam(daysFromNow: 1)),
            URLQueryItem(name: "primary_release_date.lte", value: dateParam(daysFromNow: 365)),
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
        ])
    }

    static func movieRecommendations(id: Int, page: Int = 1) async throws -> PagedResult<Movie> {
        try await moviePage("/movie/\(id)/recommendations", page: page)
    }

    static func watchProviders(region: String) async throws -> [WatchProvider] {
        let data = try await fetch("/watch/providers/movie",
                                   queryItems: [URLQueryItem(name: "watch_region", value: region)])
        let root = try decode(ProviderListRaw.self, from: data)
        return root.results
            .filter { $0.isAvailable(in: region) }
            .sorted { $0.priority(in: region) < $1.priority(in: region) }
            .map { WatchProvider(id: $0.providerId, name: $0.providerName, logoPath: $0.logoPath) }
    }

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

    // /discover/movie honors the region and release filters the curated /movie/* lists ignore.
    private static func discoverMovies(page: Int, extra: [URLQueryItem]) async throws -> PagedResult<Movie> {
        try await moviePage("/discover/movie", page: page, queryItems: extra)
    }

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
        movie.imdbID = mv.imdbID ?? mv.externalIDs?.imdbID
        movie.wikidataID = mv.externalIDs?.wikidataID

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

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
        // Films with a US theatrical release in the last six weeks, most popular
        // first. This uses the region release date (not `primary_release_date`) so a
        // film that premiered abroad earlier but is in US theatres now still shows —
        // "now playing" is about what's on screens here, so a current re-release
        // legitimately belongs (unlike Coming Soon, which stays on primary date).
        try await discoverMovies(page: page, extra: [
            URLQueryItem(name: "with_release_type", value: "2|3"),
            URLQueryItem(name: "release_date.gte", value: dateParam(daysFromNow: -42)),
            URLQueryItem(name: "release_date.lte", value: dateParam(daysFromNow: 0)),
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
        ])
    }

    static func moviesPopular(page: Int) async throws -> PagedResult<Movie> {
        // `vote_count.gte` filters out thin duplicate records that ride a title's
        // popularity without the audience to back it — e.g. a 9-vote second "The
        // Odyssey" trailing Nolan's. Popularity alone (page views / searches) can't
        // tell them apart; a vote floor can.
        try await discoverMovies(page: page, extra: [
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            URLQueryItem(name: "vote_count.gte", value: "100"),
        ])
    }

    static func moviesComingSoon(page: Int) async throws -> PagedResult<Movie> {
        // Films with an original release still to come (within the next year), most
        // anticipated first. `primary_release_date` excludes re-releases of old films
        // that a plain region release-date filter would otherwise pull in.
        try await discoverMovies(page: page, extra: [
            URLQueryItem(name: "primary_release_date.gte", value: dateParam(daysFromNow: 1)),
            URLQueryItem(name: "primary_release_date.lte", value: dateParam(daysFromNow: 365)),
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
        ])
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

    /// The Discover feeds. `/discover/movie` honors the region, original-language,
    /// and release filters that the curated `/movie/*` lists silently ignore — so a
    /// title that merely ranks high globally but has no US release (and isn't in the
    /// user's language) no longer leaks into Popular / Now Playing / Coming Soon.
    private static func discoverMovies(page: Int, extra: [URLQueryItem]) async throws -> PagedResult<Movie> {
        try await moviePage("/discover/movie", page: page, queryItems: extra)
    }

    /// A `yyyy-MM-dd` param offset from today, for Discover release-date windows.
    private static func dateParam(daysFromNow days: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return DateFormatter.iso8601DAw.string(from: date)
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

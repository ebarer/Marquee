//
//  TMDBWrapper+TV.swift
//  MovieTracker
//

import Foundation

extension TMDBWrapper {
    static func getShow(id: Int) async throws -> Show {
        // Content ratings return every region (not gated by `certification_country`),
        // so no `certified:` flag here — the region pick happens in `certification()`.
        let data = try await fetch(
            "/tv/\(id)",
            queryItems: [
                URLQueryItem(name: "append_to_response",
                             value: "aggregate_credits,content_ratings,videos,watch/providers"),
            ]
        )
        return translate(show: try decode(ShowRaw.self, from: data))
    }

    static func getSeason(showID: Int, seasonNumber: Int) async throws -> Season {
        let data = try await fetch("/tv/\(showID)/season/\(seasonNumber)")
        var season = try decode(SeasonRaw.self, from: data).season()
        // Stamp the show id onto each episode (TMDB omits it) so a standalone episode
        // can address its watched record.
        season.episodes = season.episodes.map { var e = $0; e.showTmdbID = showID; return e }
        return season
    }

    /// A cheap `/tv/{id}` hit (no appends) translated to a `Show` — carries the season list,
    /// last-air date and status that list/search payloads omit, so cards can lazily upgrade
    /// their season count *and* year range from a single call.
    static func showSummary(id: Int) async throws -> Show {
        let data = try await fetch("/tv/\(id)")
        return translate(show: try decode(ShowRaw.self, from: data))
    }

    static func showRecommendations(id: Int, page: Int = 1) async throws -> PagedResult<Show> {
        try await showPage("/tv/\(id)/recommendations", page: page)
    }

    static func searchForShows(query: String, page: Int = 1) async throws -> PagedResult<Show> {
        guard !query.isEmpty else { return .empty }
        return try await showPage("/search/tv", page: page,
                                  queryItems: [URLQueryItem(name: "query", value: query)])
    }

    static func showsAiringToday(page: Int) async throws -> PagedResult<Show> {
        try await showPage("/tv/airing_today", page: page)
    }

    static func showsPopular(page: Int) async throws -> PagedResult<Show> {
        // `vote_count.gte` filters thin records the same way `moviesPopular` does.
        try await discoverShows(page: page, extra: [
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            URLQueryItem(name: "vote_count.gte", value: "100"),
        ])
    }

    static func showsOnTheAir(page: Int) async throws -> PagedResult<Show> {
        try await showPage("/tv/on_the_air", page: page)
    }

    private static func discoverShows(page: Int, extra: [URLQueryItem]) async throws -> PagedResult<Show> {
        try await showPage("/discover/tv", page: page, queryItems: extra)
    }

    private static func showPage(_ path: String, page: Int,
                                 queryItems: [URLQueryItem] = []) async throws -> PagedResult<Show> {
        guard page > 0 else {
            throw FetchError.decode("Invalid page number (index starts at 1).")
        }
        let data = try await fetch(path, queryItems: queryItems + [
            URLQueryItem(name: "page", value: String(page))
        ])
        let root = try decode(RootRaw<ShowRaw>.self, from: data)
        return PagedResult(items: root.results.map(translate(show:)),
                           totalResults: root.totalResults, totalPages: root.totalPages)
    }

    static func translate(show sh: ShowRaw) -> Show {
        var show = Show(id: sh.id, name: sh.name)

        if let overview = sh.overview, !overview.isEmpty {
            show.overview = overview
        }

        show.poster = sh.poster
        show.background = sh.background
        show.rating = sh.rating
        show.popularity = sh.popularity
        show.voteCount = sh.voteCount
        show.status = sh.status
        show.firstAirDate = sh.firstAirDateString?.toDate(format: .iso8601DAw)
        show.lastAirDate = sh.lastAirDateString?.toDate(format: .iso8601DAw)
        show.certification = sh.certification()
        show.genres = sh.genres()
        show.networks = sh.networks()
        show.originCountry = sh.originCountry
        show.trailers = sh.trailers()
        show.creators = sh.creators()
        show.recurringCast = sh.recurringCast()
        show.seasons = sh.seasonsList()
        show.watchByRegion = sh.watchByRegion()

        return show
    }
}

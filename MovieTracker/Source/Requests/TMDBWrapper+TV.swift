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
        var show = translate(show: try decode(ShowRaw.self, from: data))
        // The one response carrying every field, so the one place that can vouch for it.
        show.isFullDetail = true
        return show
    }

    static func getSeason(showID: Int, seasonNumber: Int) async throws -> Season {
        let data = try await fetch(
            "/tv/\(showID)/season/\(seasonNumber)",
            queryItems: [URLQueryItem(name: "append_to_response", value: "aggregate_credits")]
        )
        var season = try decode(SeasonRaw.self, from: data).season()
        // Stamp the show id onto each episode (TMDB omits it) so a standalone episode
        // can address its watched record.
        season.episodes = season.episodes.map {
            var episode = $0
            episode.showTmdbID = showID
            return episode
        }
        return season
    }

    /// A cheap `/tv/{id}` hit carrying the season list, last-air date and status that
    /// list/search payloads omit, so cards can lazily upgrade from a single call.
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

    static func showsPopular(page: Int) async throws -> PagedResult<Show> {
        // `vote_count.gte` filters thin records the same way `moviesPopular` does.
        try await discoverShows(page: page, extra: [
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            URLQueryItem(name: "vote_count.gte", value: "100"),
        ])
    }

    static func showsOnTheAir(page: Int) async throws -> PagedResult<Show> {
        // `/tv/on_the_air` is curated and ignores every filter, so an air-date window on
        // discover stands in for it — wide enough that a weekly series doesn't drop out.
        try await discoverShows(page: page, extra: [
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            URLQueryItem(name: "air_date.gte", value: dateParam(daysFromNow: -14)),
            URLQueryItem(name: "air_date.lte", value: dateParam(daysFromNow: 7)),
            // News strips like TMZ, talk, soaps and reality, cut by genre *and* by type
            // because TMDB tags a given show under only one of the two.
            URLQueryItem(name: "without_genres", value: "10763,10767,10766,10764"),
            URLQueryItem(name: "with_type", value: "0|2|4"),
            // Low enough that a week-one premiere still ranks.
            URLQueryItem(name: "vote_count.gte", value: "10"),
        ])
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
        show.nextAirDate = sh.nextEpisodeRaw?.airDateString?.toDate(format: .iso8601DAw)
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

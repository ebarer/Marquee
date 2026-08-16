//
//  TMDBTVDecodingTests.swift
//  MarqueeTests
//
//  TV raw-response decoding and raw->domain translation, offline.
//

import Testing
import Foundation
@testable import Marquee

@Suite struct TMDBTVDecodingTests {
    private var region: String { NSLocale.current.region?.identifier ?? "US" }

    private func decodeShow(_ json: String) throws -> TMDBWrapper.ShowRaw {
        try TMDBWrapper.decode(TMDBWrapper.ShowRaw.self, from: Data(json.utf8))
    }

    private func decodeSeason(_ json: String) throws -> TMDBWrapper.SeasonRaw {
        try TMDBWrapper.decode(TMDBWrapper.SeasonRaw.self, from: Data(json.utf8))
    }

    private func fullShowJSON() -> String {
        """
        {
          "id": 1399, "name": "Game of Thrones",
          "overview": "Nine noble families fight for control.",
          "poster_path": "/p.jpg", "backdrop_path": "/bg.jpg",
          "vote_average": 8.4, "popularity": 100.0, "vote_count": 20000,
          "status": "Ended",
          "first_air_date": "2011-04-17", "last_air_date": "2019-05-19",
          "genres": [{"name":"Sci-Fi & Fantasy"},{"name":"Drama"},{"name":"Action & Adventure"}],
          "networks": [{"id":49,"name":"HBO"}],
          "created_by": [{"id":9813,"name":"David Benioff","profile_path":"/d.jpg"}],
          "seasons": [
            {"id":3627,"season_number":0,"name":"Specials","air_date":"2010-12-05","episode_count":14,"poster_path":"/s0.jpg"},
            {"id":3624,"season_number":1,"name":"Season 1","air_date":"2011-04-17","episode_count":10,"poster_path":"/s1.jpg"},
            {"id":3625,"season_number":2,"name":"Season 2","air_date":"2012-04-01","episode_count":10}
          ],
          "videos": {"results":[
            {"id":"v1","name":"Trailer","key":"xyz","type":"Trailer","site":"YouTube","official":true,"published_at":"2011-01-01"}
          ]},
          "aggregate_credits": {"cast":[
            {"id":1,"name":"Second Billed","profile_path":"/a.jpg","order":2,"total_episode_count":70,"roles":[{"character":"Hero"}]},
            {"id":2,"name":"Departed Lead","profile_path":null,"order":0,"total_episode_count":30,"roles":[{"character":"Sidekick"}]},
            {"id":3,"name":"Tied Actor","order":5,"total_episode_count":70,"roles":[{"character":"Villain"}]},
            {"id":4,"name":"One Off Guest","order":1,"total_episode_count":1,"roles":[{"character":"Waiter"}]}
          ]},
          "content_ratings": {"results":[
            {"iso_3166_1":"\(region)","rating":"TV-MA"},
            {"iso_3166_1":"US","rating":"TV-14"}
          ]},
          "watch/providers": {"results":{"\(region)":{"link":"https://jw","flatrate":[
            {"provider_id":8,"provider_name":"Netflix","logo_path":"/n.jpg","display_priority":1}
          ]}}}
        }
        """
    }

    @Test func decodesRemappedKeys() throws {
        let raw = try decodeShow(fullShowJSON())
        #expect(raw.id == 1399)
        #expect(raw.name == "Game of Thrones")
        #expect(raw.poster == "/p.jpg")
        #expect(raw.background == "/bg.jpg")
        #expect(raw.rating == 8.4)
        #expect(raw.status == "Ended")
    }

    @Test func genresCapAtTwo() throws {
        #expect(try decodeShow(fullShowJSON()).genres() == ["Sci-Fi & Fantasy", "Drama"])
    }

    @Test func networksMapped() throws {
        #expect(try decodeShow(fullShowJSON()).networks() == ["HBO"])
    }

    @Test func creatorsMapped() throws {
        let creators = try decodeShow(fullShowJSON()).creators()
        #expect(creators.map(\.name) == ["David Benioff"])
        #expect(creators.first?.type == .Crew)
    }

    @Test func contentRatingPrefersRegionThenUS() throws {
        #expect(try decodeShow(fullShowJSON()).certification() == "TV-MA")
    }

    @Test func contentRatingFallsBackToUS() throws {
        let json = #"{"id":1,"name":"X","content_ratings":{"results":[{"iso_3166_1":"ZZ","rating":"18"},{"iso_3166_1":"US","rating":"TV-PG"}]}}"#
        #expect(try decodeShow(json).certification() == "TV-PG")
    }

    @Test func contentRatingNilWhenAbsent() throws {
        #expect(try decodeShow(#"{"id":1,"name":"X"}"#).certification() == nil)
    }

    /// Billing order among the regulars, so a lead who left partway (30 of 70 episodes) still
    /// leads — and a one-episode guest billed second doesn't jump any of them.
    @Test func recurringCastRanksRegularsByBillingOrderThenGuestsByPresence() throws {
        let cast = try decodeShow(fullShowJSON()).recurringCast()
        #expect(cast.map(\.id) == [2, 1, 3, 4])
        #expect(cast.first?.role == "Sidekick")
        #expect(cast.allSatisfy { $0.type == .Cast })
    }

    @Test func recurringCastEmptyWithoutAggregateCredits() throws {
        #expect(try decodeShow(#"{"id":1,"name":"X"}"#).recurringCast().isEmpty)
    }

    @Test func seasonsListKeepsSpecialsButRegularSeasonsExcludeThem() throws {
        let show = TMDBWrapper.translate(show: try decodeShow(fullShowJSON()))
        #expect(show.seasons.map(\.seasonNumber).sorted() == [0, 1, 2])
        #expect(show.regularSeasons.map(\.seasonNumber) == [1, 2])
        #expect(show.seasons.first { $0.seasonNumber == 1 }?.startYear == 2011)
    }

    @Test func translateShowMapsAllFields() throws {
        let show = TMDBWrapper.translate(show: try decodeShow(fullShowJSON()))
        #expect(show.id == 1399)
        #expect(show.title == "Game of Thrones")
        #expect(show.overview == "Nine noble families fight for control.")
        #expect(show.firstAirDate == .utc(2011, 4, 17))
        #expect(show.lastAirDate == .utc(2019, 5, 19))
        #expect(show.yearRange == "2011–2019")
        #expect(show.certification == "TV-MA")
        #expect(show.genres == ["Sci-Fi & Fantasy", "Drama"])
        #expect(show.trailers?.first?.key == "xyz")
        #expect(show.watchByRegion?[region]?.providers.first?.name == "Netflix")
    }

    @Test func translateShowDropsEmptyOverview() throws {
        let show = TMDBWrapper.translate(show: try decodeShow(#"{"id":1,"name":"X","overview":""}"#))
        #expect(show.overview == nil)
    }

    @Test func ongoingShowYearRangeIsPresent() throws {
        let json = #"{"id":1,"name":"X","status":"Returning Series","first_air_date":"2021-09-01"}"#
        #expect(TMDBWrapper.translate(show: try decodeShow(json)).yearRange == "2021–Present")
    }

    @Test func nextAirDateComesFromScheduledEpisode() throws {
        let json = #"{"id":1,"name":"X","status":"Returning Series","next_episode_to_air":{"id":9,"air_date":"2026-09-04","episode_number":5,"season_number":3}}"#
        #expect(TMDBWrapper.translate(show: try decodeShow(json)).nextAirDate == .utc(2026, 9, 4))
    }

    @Test func nextAirDateNilForEndedShow() throws {
        #expect(TMDBWrapper.translate(show: try decodeShow(fullShowJSON())).nextAirDate == nil)
    }

    // MARK: - Season detail

    private func seasonJSON() -> String {
        """
        {
          "id":3624,"season_number":1,"name":"Season 1","air_date":"2011-04-17","poster_path":"/s1.jpg",
          "episodes":[
            {"id":63058,"name":"The Kingsroad","overview":"Journey.","runtime":56,"vote_average":7.9,
             "air_date":"2011-04-24","episode_number":2,"season_number":1},
            {"id":63057,"name":"Winter Is Coming","overview":"Ned.","still_path":"/e1.jpg","runtime":62,
             "vote_average":8.0,"air_date":"2011-04-17","episode_number":1,"season_number":1,
             "guest_stars":[
               {"id":100,"order":1,"name":"Guest B","character":"Bran's Friend","profile_path":null},
               {"id":101,"order":0,"name":"Guest A","character":"Villager","profile_path":"/g.jpg"}
             ]}
          ]
        }
        """
    }

    @Test func seasonEpisodesSortedByNumber() throws {
        let season = try decodeSeason(seasonJSON()).season()
        #expect(season.episodes.map(\.episodeNumber) == [1, 2])
        #expect(season.startYear == 2011)
    }

    @Test func episodeStillRuntimeAndScore() throws {
        let episodes = try decodeSeason(seasonJSON()).season().episodes
        let first = episodes[0]
        #expect(first.still == "/e1.jpg")
        #expect(first.duration == "1 hr 2 min")
        #expect(first.rating == 8.0)
        #expect(episodes[1].still == nil)   // missing still tolerated
    }

    @Test func episodeGuestStarsSortedByOrder() throws {
        let first = try decodeSeason(seasonJSON()).season().episodes[0]
        #expect(first.guestCast.map(\.name) == ["Guest A", "Guest B"])
        #expect(first.guestCast.first?.role == "Villager")
    }

    // MARK: - Pagination

    @Test func rootRawDecodesShowPagination() throws {
        let json = #"{"results":[{"id":1,"name":"A"}],"total_results":50,"total_pages":5}"#
        let root = try TMDBWrapper.decode(TMDBWrapper.RootRaw<TMDBWrapper.ShowRaw>.self, from: Data(json.utf8))
        #expect(root.totalResults == 50)
        #expect(root.totalPages == 5)
        #expect(root.results.first?.name == "A")
    }
}

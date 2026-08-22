//
//  BulkWatchedDatingTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

/// Bulk marking back-dates episodes to when they aired, so a back-filled show doesn't land on today.
@Suite @MainActor struct BulkWatchedDatingTests {
    private let store = makeInMemoryStore()

    private func makeSeason(_ number: Int, episodes: [(Int, Date?)],
                            airDate: Date? = nil) -> Season {
        var season = Season(id: number * 100, seasonNumber: number, name: "Season \(number)",
                            episodeCount: episodes.count)
        season.airDate = airDate ?? episodes.first?.1
        season.episodes = episodes.map { number, air in
            var episode = Episode(id: number + season.id, seasonNumber: season.seasonNumber,
                                  episodeNumber: number, name: "E\(number)")
            episode.airDate = air
            episode.runtime = 30
            return episode
        }
        return season
    }

    private func watchedDates(showID: Int, season: Int) -> [Int: Date] {
        var dates: [Int: Date] = [:]
        for episode in WatchedEpisode.all(showTmdbID: showID, in: store.context)
        where episode.seasonNumber == season {
            dates[episode.episodeNumber] = episode.watchedAt
        }
        return dates
    }

    @Test func markingASeasonDatesEachEpisodeToItsAirDate() {
        var show = Show(id: 1, name: "Back Catalogue")
        show.status = "Ended"
        let season = makeSeason(1, episodes: [
            (1, .utc(2019, 1, 6)), (2, .utc(2019, 1, 13)), (3, .utc(2019, 1, 20))
        ])
        show.seasons = [season]

        store.setSeasonWatched(true, show: show, season: season)

        let dates = watchedDates(showID: 1, season: 1)
        #expect(dates[1] == .utc(2019, 1, 6))
        #expect(dates[2] == .utc(2019, 1, 13))
        #expect(dates[3] == .utc(2019, 1, 20))
    }

    @Test func markingASeasonDatesItsSnapshotToTheFinale() {
        var show = Show(id: 2, name: "Back Catalogue")
        show.status = "Ended"
        let season = makeSeason(1, episodes: [(1, .utc(2019, 1, 6)), (2, .utc(2019, 1, 13))])
        show.seasons = [season]

        store.setSeasonWatched(true, show: show, season: season)

        let snapshot = WatchedSeason.find(showTmdbID: 2, seasonNumber: 1, in: store.context)
        #expect(snapshot?.watchedAt == .utc(2019, 1, 13))
    }

    @Test func markingAWholeShowDatesEverySeasonToItsOwnAirDates() async {
        var show = Show(id: 3, name: "Long Runner")
        show.status = "Ended"
        show.seasons = [
            makeSeason(1, episodes: [(1, .utc(2018, 2, 4)), (2, .utc(2018, 2, 11))]),
            makeSeason(2, episodes: [(1, .utc(2019, 3, 3)), (2, .utc(2019, 3, 10))])
        ]

        await store.setShowWatched(true, show: show)

        #expect(watchedDates(showID: 3, season: 1)[1] == .utc(2018, 2, 4))
        #expect(watchedDates(showID: 3, season: 2)[2] == .utc(2019, 3, 10))
    }

    @Test func unhydratedSeasonFallsBackToThePremiere() {
        var show = Show(id: 4, name: "Uncached")
        show.status = "Ended"
        var season = Season(id: 400, seasonNumber: 1, name: "Season 1", episodeCount: 3)
        season.airDate = .utc(2015, 9, 1)
        show.seasons = [season]

        store.setSeasonWatched(true, show: show, season: season)

        let dates = watchedDates(showID: 4, season: 1)
        #expect(dates.count == 3)
        #expect(Set(dates.values) == [.utc(2015, 9, 1)])
    }

    @Test func togglingASingleEpisodeStillDatesToToday() {
        var show = Show(id: 5, name: "Live Viewer")
        show.status = "Returning Series"
        let season = makeSeason(1, episodes: [(1, .utc(2019, 1, 6)), (2, .utc(2019, 1, 13))])
        show.seasons = [season]

        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 1)

        let watched = watchedDates(showID: 5, season: 1)[1]
        #expect(watched != nil)
        #expect(abs(watched!.timeIntervalSinceNow) < 60)
    }

    @Test func markingNextEpisodeDatesToToday() {
        var show = Show(id: 6, name: "Catching Up")
        show.status = "Returning Series"
        let season = makeSeason(1, episodes: [(1, .utc(2019, 1, 6)), (2, .utc(2019, 1, 13))])
        show.seasons = [season]

        store.markNextEpisodeWatched(show: show, season: season)

        let watched = watchedDates(showID: 6, season: 1)[1]
        #expect(watched != nil)
        #expect(abs(watched!.timeIntervalSinceNow) < 60)
    }

    @Test func markingASeasonRecordsEachEpisodeRuntime() {
        var show = Show(id: 8, name: "Timed")
        show.status = "Ended"
        let season = makeSeason(1, episodes: [(1, .utc(2019, 1, 6)), (2, .utc(2019, 1, 13))])
        show.seasons = [season]

        store.setSeasonWatched(true, show: show, season: season)

        let runtimes = WatchedEpisode.all(showTmdbID: 8, in: store.context).map(\.runtime)
        #expect(runtimes.count == 2)
        #expect(runtimes.allSatisfy { $0 == 30 })
    }


}

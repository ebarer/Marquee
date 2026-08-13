//
//  WatchedSeasonTests.swift
//  MarqueeTests
//
//  Season-level TV watched tracking: episodes are the source of truth; seasons and shows
//  derive; completing a season writes a WatchedSeason snapshot for the Watched list.
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@MainActor
@Suite struct WatchedSeasonTests {
    private func makeSeason(_ number: Int, episodes: Int, airStart: Date? = nil) -> Season {
        var season = Season(id: number * 100, seasonNumber: number, name: "Season \(number)",
                            episodeCount: episodes)
        season.airDate = airStart
        season.episodes = (1...max(episodes, 1)).map { i in
            var e = Episode(id: number * 1000 + i, seasonNumber: number, episodeNumber: i, name: "E\(i)")
            e.airDate = airStart
            return e
        }
        return season
    }

    private func makeShow(id: Int, seasons: [Season]) -> Show {
        var show = Show(id: id, name: "Show \(id)")
        show.seasons = seasons
        return show
    }

    @Test func markingAllEpisodesCompletesSeasonAndWritesSnapshot() {
        let store = makeInMemoryStore()
        let season = makeSeason(1, episodes: 3, airStart: .utc(2020, 1, 1))
        let show = makeShow(id: 5, seasons: [season])

        store.setSeasonWatched(true, show: show, season: season)

        #expect(store.isSeasonWatched(season, showID: 5))
        let snapshot = WatchedSeason.find(showTmdbID: 5, seasonNumber: 1, in: store.context)
        #expect(snapshot?.showName == "Show 5")
        #expect(snapshot?.seasonName == "Season 1")
    }

    @Test func partialSeasonIsNotInWatched() {
        let store = makeInMemoryStore()
        let season = makeSeason(1, episodes: 3)
        let show = makeShow(id: 5, seasons: [season])

        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 1)

        #expect(!store.isSeasonWatched(season, showID: 5))                 // not fully watched
        // Watched holds completed seasons only — a partial one lives on the Watch List instead.
        #expect(WatchedSeason.find(showTmdbID: 5, seasonNumber: 1, in: store.context) == nil)
    }

    @Test func droppingBelowCompleteRemovesFromWatched() {
        let store = makeInMemoryStore()
        let season = makeSeason(1, episodes: 3)
        let show = makeShow(id: 5, seasons: [season])

        for i in 1...3 { store.toggleEpisodeWatched(show: show, season: season, episodeNumber: i) }
        #expect(store.isSeasonWatched(season, showID: 5))
        #expect(WatchedSeason.find(showTmdbID: 5, seasonNumber: 1, in: store.context) != nil)

        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 2)  // 2/3 — no longer complete
        #expect(!store.isSeasonWatched(season, showID: 5))
        #expect(WatchedSeason.find(showTmdbID: 5, seasonNumber: 1, in: store.context) == nil)
    }

    @Test func showIsFullyWatchedOnlyWhenEverySeasonIs() {
        let store = makeInMemoryStore()
        let s1 = makeSeason(1, episodes: 2), s2 = makeSeason(2, episodes: 2)
        let show = makeShow(id: 6, seasons: [s1, s2])

        store.setSeasonWatched(true, show: show, season: s1)
        #expect(!store.isShowFullyWatched(show))

        store.setSeasonWatched(true, show: show, season: s2)
        #expect(store.isShowFullyWatched(show))
    }

    @Test func cachedFullyWatchedFlagStaysInSync() {
        let store = makeInMemoryStore()
        let s1 = makeSeason(1, episodes: 2), s2 = makeSeason(2, episodes: 2)
        let show = makeShow(id: 42, seasons: [s1, s2])

        #expect(!store.isShowWatchedCached(showID: 42))

        store.setSeasonWatched(true, show: show, season: s1)
        #expect(!store.isShowWatchedCached(showID: 42))          // only one season complete

        store.setSeasonWatched(true, show: show, season: s2)
        #expect(store.isShowWatchedCached(showID: 42))           // fully watched → cached true

        store.unwatchSeason(showID: 42, seasonNumber: 2)
        #expect(!store.isShowWatchedCached(showID: 42))          // dropped below complete → cleared
    }

    @Test func markingShowWatchedMarksAllSeasonsAndLeavesWatchList() async {
        let store = makeInMemoryStore()
        let show = makeShow(id: 7, seasons: [makeSeason(1, episodes: 2), makeSeason(2, episodes: 2)])
        store.addToWatchList(show)

        await store.setShowWatched(true, show: show)

        #expect(store.isShowFullyWatched(show))
        #expect(!store.isInWatchList(show))
        #expect(WatchedSeason.find(showTmdbID: 7, seasonNumber: 1, in: store.context) != nil)
        #expect(WatchedSeason.find(showTmdbID: 7, seasonNumber: 2, in: store.context) != nil)
    }

    @Test func unwatchSeasonClearsEpisodesAndSnapshot() {
        let store = makeInMemoryStore()
        let season = makeSeason(1, episodes: 2)
        let show = makeShow(id: 8, seasons: [season])
        store.setSeasonWatched(true, show: show, season: season)

        store.unwatchSeason(showID: 8, seasonNumber: 1)

        #expect(store.watchedEpisodeNumbers(showID: 8, season: 1).isEmpty)
        #expect(WatchedSeason.find(showTmdbID: 8, seasonNumber: 1, in: store.context) == nil)
    }

    @Test func deduplicateCollapsesDuplicateRecords() {
        let store = makeInMemoryStore()
        store.context.insert(WatchedEpisode(showTmdbID: 9, seasonNumber: 1, episodeNumber: 1))
        store.context.insert(WatchedEpisode(showTmdbID: 9, seasonNumber: 1, episodeNumber: 1))
        store.context.insert(WatchedSeason(showTmdbID: 9, seasonNumber: 1, showName: "X",
                                           seasonName: "Season 1", posterPath: nil, airDate: nil))
        store.context.insert(WatchedSeason(showTmdbID: 9, seasonNumber: 1, showName: "X",
                                           seasonName: "Season 1", posterPath: nil, airDate: nil))
        store.save()

        WatchedEpisode.deduplicate(in: store.context)
        WatchedSeason.deduplicate(in: store.context)

        #expect(store.watchedEpisodeNumbers(showID: 9, season: 1) == [1])
        let seasons = (try? store.context.fetch(FetchDescriptor<WatchedSeason>())) ?? []
        #expect(seasons.filter { $0.showTmdbID == 9 }.count == 1)
    }

    @Test func watchedSectionIncludesSeasonRows() async {
        let store = makeInMemoryStore()
        let season = makeSeason(2, episodes: 2, airStart: .utc(2024, 6, 1))
        let show = makeShow(id: 10, seasons: [season])
        store.setSeasonWatched(true, show: show, season: season)

        let sections = await store.sections(for: .watched(sort: .releaseDate),
                                             ascending: false, filter: "")
        let rows = sections.flatMap(\.entries)
        #expect(rows.contains { $0.mediaType == .tv && $0.seasonNumber == 2 && $0.tmdbID == 10 })
    }

    // MARK: - Season ratings

    private func completedSeason(_ store: PersistenceCoordinator, showID: Int = 20) -> Season {
        let season = makeSeason(1, episodes: 2, airStart: .utc(2022, 1, 1))
        store.setSeasonWatched(true, show: makeShow(id: showID, seasons: [season]), season: season)
        return season
    }

    @Test func seasonRatingRoundTrips() {
        let store = makeInMemoryStore()
        _ = completedSeason(store)

        store.setSeasonRating(4, showID: 20, season: 1)

        #expect(store.seasonRating(showID: 20, season: 1) == 4)
    }

    @Test func seasonRatingSnapsToHalfStars() {
        let store = makeInMemoryStore()
        _ = completedSeason(store)

        store.setSeasonRating(3.7, showID: 20, season: 1)
        #expect(store.seasonRating(showID: 20, season: 1) == 3.5)

        store.setSeasonRating(4.24, showID: 20, season: 1)
        #expect(store.seasonRating(showID: 20, season: 1) == 4)
    }

    @Test func zeroOrNilClearsTheSeasonRating() {
        let store = makeInMemoryStore()
        _ = completedSeason(store)
        store.setSeasonRating(5, showID: 20, season: 1)

        store.setSeasonRating(0, showID: 20, season: 1)
        #expect(store.seasonRating(showID: 20, season: 1) == nil)

        store.setSeasonRating(5, showID: 20, season: 1)
        store.setSeasonRating(nil, showID: 20, season: 1)
        #expect(store.seasonRating(showID: 20, season: 1) == nil)
    }

    // A rating hangs off the WatchedSeason snapshot, which only exists once complete.
    @Test func ratingAnIncompleteSeasonIsANoOp() {
        let store = makeInMemoryStore()
        let season = makeSeason(1, episodes: 3, airStart: .utc(2022, 1, 1))
        let show = makeShow(id: 21, seasons: [season])
        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 1)

        store.setSeasonRating(4, showID: 21, season: 1)

        #expect(store.seasonRating(showID: 21, season: 1) == nil)
    }

    @Test func unwatchingASeasonDiscardsItsRating() {
        let store = makeInMemoryStore()
        _ = completedSeason(store)
        store.setSeasonRating(5, showID: 20, season: 1)

        store.unwatchSeason(showID: 20, seasonNumber: 1)

        #expect(store.seasonRating(showID: 20, season: 1) == nil)
    }

    // Dedupe keeps the earliest record but must not lose a rating written on a later copy.
    @Test func deduplicateKeepsARatingFromTheDiscardedCopy() {
        let store = makeInMemoryStore()
        let keep = WatchedSeason(showTmdbID: 30, seasonNumber: 1, showName: "S", seasonName: "S1",
                                 posterPath: nil, airDate: nil, episodeCount: 2)
        keep.addedAt = .utc(2024, 1, 1)
        let drop = WatchedSeason(showTmdbID: 30, seasonNumber: 1, showName: "S", seasonName: "S1",
                                 posterPath: nil, airDate: nil, episodeCount: 2)
        drop.addedAt = .utc(2024, 6, 1)
        drop.userRating = 4.5
        store.context.insert(keep)
        store.context.insert(drop)

        WatchedSeason.deduplicate(in: store.context)

        #expect(store.seasonRating(showID: 30, season: 1) == 4.5)
    }
}

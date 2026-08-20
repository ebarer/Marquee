//
//  ShowBadgeStateTests.swift
//  MarqueeTests
//
//  Rows and cards badge a show from its id alone, with no loaded Show: watched, then
//  partially watched, then on the Watch List. `ShowRow.effectiveStatus` reads these three.
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@MainActor
@Suite struct ShowBadgeStateTests {
    private func makeShow(id: Int = 1, seasons: Int = 2, episodes: Int = 2) -> Show {
        var show = Show(id: id, name: "Show \(id)")
        show.seasons = (1...seasons).map { number in
            var season = Season(id: number * 100, seasonNumber: number, name: "Season \(number)",
                                episodeCount: episodes)
            season.episodes = (1...episodes).map { episodeNumber in
                var episode = Episode(id: number * 1000 + episodeNumber, seasonNumber: number,
                                      episodeNumber: episodeNumber, name: "E\(episodeNumber)")
                episode.airDate = .utc(2020, 1, 1)
                return episode
            }
            return season
        }
        return show
    }

    private func badge(_ store: PersistenceCoordinator, _ showID: Int) -> PosterStatus? {
        if store.isShowWatchedCached(showID: showID) { return .watched }
        if store.hasWatchedEpisodes(showID: showID) { return .partial }
        if store.isInWatchList(showID: showID) { return .watchList }
        return nil
    }

    @Test func untrackedShowHasNoBadge() {
        let store = makeInMemoryStore()
        #expect(badge(store, 1) == nil)
        #expect(store.hasWatchedEpisodes(showID: 1) == false)
        #expect(store.isInWatchList(showID: 1) == false)
        #expect(store.isShowWatchedCached(showID: 1) == false)
    }

    @Test func bookmarkedShowReadsAsWatchList() {
        let store = makeInMemoryStore()
        let show = makeShow()
        store.addToWatchList(show)

        #expect(store.isInWatchList(showID: show.id))
        #expect(badge(store, show.id) == .watchList)
    }

    @Test func oneWatchedEpisodeReadsAsPartial() {
        let store = makeInMemoryStore()
        let show = makeShow()
        store.toggleEpisodeWatched(show: show, season: show.seasons[0], episodeNumber: 1)

        #expect(store.hasWatchedEpisodes(showID: show.id))
        #expect(badge(store, show.id) == .partial)
    }

    @Test func fullyWatchedShowReadsAsWatched() async {
        let store = makeInMemoryStore()
        let show = makeShow()
        await store.setShowWatched(true, show: show)

        #expect(store.isShowWatchedCached(showID: show.id))
        #expect(badge(store, show.id) == .watched)
    }

    // Watched wins over partial: a fully-watched show still has watched episodes.
    @Test func watchedTakesPrecedenceOverPartial() async {
        let store = makeInMemoryStore()
        let show = makeShow()
        await store.setShowWatched(true, show: show)

        #expect(store.hasWatchedEpisodes(showID: show.id))
        #expect(badge(store, show.id) == .watched)
    }

    @Test func unwatchingASeasonDropsBackToPartial() async {
        let store = makeInMemoryStore()
        let show = makeShow()
        await store.setShowWatched(true, show: show)

        store.unwatchSeason(showID: show.id, seasonNumber: 2)

        #expect(store.isShowWatchedCached(showID: show.id) == false)
        #expect(badge(store, show.id) == .partial)
    }

    @Test func isInWatchListByIDNeverCreatesTheList() {
        let store = makeInMemoryStore()
        #expect(store.isInWatchList(showID: 99) == false)
        #expect(store.lists.contains { $0.isWatchList } == false)
    }

    @Test func idOnlyReadsIgnoreAMovieWithTheSameTMDBID() {
        let store = makeInMemoryStore()
        let movie = makeMovie(id: 500, title: "Same ID")
        store.setWatched(true, for: movie)

        #expect(store.isShowWatchedCached(showID: 500) == false)
        #expect(badge(store, 500) == nil)
    }
}

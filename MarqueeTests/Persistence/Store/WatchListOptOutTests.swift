//
//  WatchListOptOutTests.swift
//  MarqueeTests
//
//  An in-progress show is auto-added to the Watch List, so removing one has to persist the
//  choice — otherwise the next reconcile puts it straight back.
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@MainActor
@Suite struct WatchListOptOutTests {
    private func makeSeason(_ number: Int, episodes: Int) -> Season {
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

    private func makeShow(id: Int = 1, seasons: Int = 2, episodes: Int = 3) -> Show {
        var show = Show(id: id, name: "Show \(id)")
        show.seasons = (1...seasons).map { makeSeason($0, episodes: episodes) }
        return show
    }

    private func inProgress(_ store: PersistenceCoordinator, _ show: Show) {
        store.toggleEpisodeWatched(show: show, season: show.seasons[0], episodeNumber: 1)
    }

    @Test func dismissRemovesFromWatchListAndRecordsTheChoice() {
        let store = makeInMemoryStore()
        let show = makeShow()
        inProgress(store, show)
        #expect(store.isInWatchList(show))

        store.dismissFromWatchList(show)

        #expect(store.isInWatchList(show) == false)
        #expect(store.isWatchListDismissed(show))
    }

    // The whole point of the opt-out: progress must not bounce the show back on.
    @Test func reconcileDoesNotReAddADismissedShow() {
        let store = makeInMemoryStore()
        let show = makeShow()
        inProgress(store, show)
        store.dismissFromWatchList(show)

        store.reconcileMembership(show)
        #expect(store.isInWatchList(show) == false)

        store.toggleEpisodeWatched(show: show, season: show.seasons[0], episodeNumber: 2)
        #expect(store.isInWatchList(show) == false)
    }

    @Test func dismissDropsTheTrackedSeasonWhenOffEveryList() {
        let store = makeInMemoryStore()
        let show = makeShow()
        inProgress(store, show)
        #expect(TrackedSeason.find(showTmdbID: show.id, in: store.context) != nil)

        store.dismissFromWatchList(show)

        #expect(TrackedSeason.find(showTmdbID: show.id, in: store.context) == nil)
    }

    @Test func dismissKeepsTheTrackedSeasonWhileOnAnotherList() {
        let store = makeInMemoryStore()
        let show = makeShow()
        let custom = MediaList(name: "Custom")
        store.context.insert(custom)
        custom.add(key: show.mediaKey)
        inProgress(store, show)

        store.dismissFromWatchList(show)

        #expect(store.isInWatchList(show) == false)
        #expect(TrackedSeason.find(showTmdbID: show.id, in: store.context)?.seasonNumber == 1)
    }

    @Test func restoreClearsTheOptOutAndReturnsTheShow() {
        let store = makeInMemoryStore()
        let show = makeShow()
        inProgress(store, show)
        store.dismissFromWatchList(show)

        store.restoreToWatchList(show)

        #expect(store.isWatchListDismissed(show) == false)
        #expect(store.isInWatchList(show))
        #expect(TrackedSeason.find(showTmdbID: show.id, in: store.context)?.seasonNumber == 1)
    }

    @Test func optOutIsPerShow() {
        let store = makeInMemoryStore()
        let dismissed = makeShow(id: 1)
        let other = makeShow(id: 2)
        inProgress(store, dismissed)
        inProgress(store, other)

        store.dismissFromWatchList(dismissed)

        #expect(store.isInWatchList(dismissed) == false)
        #expect(store.isInWatchList(other))
        #expect(store.isWatchListDismissed(other) == false)
    }

    @Test func aFreshShowIsNotDismissed() {
        let store = makeInMemoryStore()
        #expect(store.isWatchListDismissed(makeShow()) == false)
    }
}

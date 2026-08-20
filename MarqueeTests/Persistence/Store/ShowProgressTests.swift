//
//  ShowProgressTests.swift
//  MarqueeTests
//
//  `showProgress` answers from persisted facts, so the show controls are right before the TMDB
//  payload lands. These pin that the cache tracks every mutation entry point.
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@MainActor
@Suite struct ShowProgressTests {
    private func makeShow(id: Int = 1, seasons: Int = 1, episodes: Int = 3, aired: Int = 3) -> Show {
        var show = Show(id: id, name: "Show \(id)")
        show.seasons = (1...seasons).map { number in
            var season = Season(id: number * 100, seasonNumber: number, name: "Season \(number)",
                                episodeCount: episodes)
            season.episodes = (1...episodes).map { episodeNumber in
                var episode = Episode(id: number * 1000 + episodeNumber, seasonNumber: number,
                                      episodeNumber: episodeNumber, name: "E\(episodeNumber)")
                episode.airDate = episodeNumber <= aired
                    ? .utc(2020, 1, 1)
                    : Date().addingTimeInterval(7 * 24 * 3600)
                return episode
            }
            return season
        }
        return show
    }

    private func stub(_ show: Show) -> Show { Show(id: show.id, name: show.name) }

    @Test func untrackedShowHasNoProgress() {
        let store = makeInMemoryStore()
        #expect(store.showProgress(showID: 1) == ShowProgress())
    }

    @Test func finishingAShowPersistsWatched() async {
        let store = makeInMemoryStore()
        let show = makeShow()
        await store.setShowWatched(true, show: show)

        let progress = store.showProgress(showID: show.id)
        #expect(progress.isWatched)
        #expect(!progress.isCaughtUp)
        #expect(progress.hasProgress)
        #expect(!progress.isTracked)          // finished leaves the Watch List
    }

    @Test func watchingEveryAiredEpisodePersistsCaughtUp() {
        let store = makeInMemoryStore()
        let show = makeShow(episodes: 4, aired: 2)
        let season = show.seasons[0]
        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 1)
        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 2)

        let progress = store.showProgress(showID: show.id)
        #expect(progress.isCaughtUp)
        #expect(!progress.isWatched)          // two episodes still to air
        #expect(progress.hasProgress)
        #expect(progress.isTracked)
    }

    @Test func anUnwatchedAiredEpisodeIsNotCaughtUp() {
        let store = makeInMemoryStore()
        let show = makeShow(episodes: 4, aired: 3)
        store.toggleEpisodeWatched(show: show, season: show.seasons[0], episodeNumber: 1)

        #expect(!store.showProgress(showID: show.id).isCaughtUp)
    }

    @Test func progressSurvivesAPayloadLessReconcile() {
        let store = makeInMemoryStore()
        let show = makeShow(episodes: 4, aired: 2)
        store.toggleEpisodeWatched(show: show, season: show.seasons[0], episodeNumber: 1)
        store.toggleEpisodeWatched(show: show, season: show.seasons[0], episodeNumber: 2)
        #expect(store.showProgress(showID: show.id).isCaughtUp)

        // A stub carries no seasons, so caught-up is unknowable — it must not be cleared.
        store.reconcileMembership(stub(show))
        #expect(store.showProgress(showID: show.id).isCaughtUp)
    }

    @Test func unwatchingASeasonClearsBothFlags() async {
        let store = makeInMemoryStore()
        let show = makeShow()
        await store.setShowWatched(true, show: show)
        #expect(store.showProgress(showID: show.id).isWatched)

        store.unwatchSeason(showID: show.id, seasonNumber: 1)

        let progress = store.showProgress(showID: show.id)
        #expect(!progress.isWatched)
        #expect(!progress.isCaughtUp)
        #expect(!progress.hasProgress)
    }

    @Test func unwatchingAnEpisodeDropsCaughtUp() {
        let store = makeInMemoryStore()
        let show = makeShow(episodes: 4, aired: 2)
        let season = show.seasons[0]
        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 1)
        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 2)
        #expect(store.showProgress(showID: show.id).isCaughtUp)

        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 2)
        #expect(!store.showProgress(showID: show.id).isCaughtUp)
    }

    @Test func finishingAfterCaughtUpClearsCaughtUp() {
        let store = makeInMemoryStore()
        let show = makeShow(episodes: 3, aired: 2)
        let season = show.seasons[0]
        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 1)
        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 2)
        #expect(store.showProgress(showID: show.id).isCaughtUp)

        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 3)

        let progress = store.showProgress(showID: show.id)
        #expect(progress.isWatched)
        #expect(!progress.isCaughtUp)         // finished outranks caught up
    }

    @Test func bookmarkingWithoutProgressReadsAsTrackedOnly() {
        let store = makeInMemoryStore()
        let show = makeShow()
        store.addToWatchList(show)

        let progress = store.showProgress(showID: show.id)
        #expect(progress.isTracked)
        #expect(!progress.hasProgress)
        #expect(!progress.isWatched)
        #expect(!progress.isCaughtUp)
    }
}

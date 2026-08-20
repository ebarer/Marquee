//
//  PartialImportTests.swift
//  MarqueeTests
//
//  CloudKit imports WatchedEpisode records in unordered batches, so a reconcile can run while a
//  completed season's episodes are still arriving. These pin what it may and may not conclude.
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@MainActor
@Suite struct PartialImportTests {
    private func makeShow(episodeCount: Int = 3) -> Show {
        var show = Show(id: 42, name: "Probe Show")
        var season = Season(id: 100, seasonNumber: 1, name: "Season 1", episodeCount: episodeCount)
        season.episodes = (1...episodeCount).map { number in
            var episode = Episode(id: 1000 + number, seasonNumber: 1,
                                  episodeNumber: number, name: "E\(number)")
            episode.airDate = .utc(2020, 1, 1)
            return episode
        }
        show.seasons = [season]
        return show
    }

    // A store as CloudKit leaves it part-way through an import: the season snapshot present, its episodes not.
    private func partiallyImported() -> PersistenceCoordinator {
        let store = makeInMemoryStore()
        let context = store.context
        context.insert(WatchedEpisode(showTmdbID: 42, seasonNumber: 1, episodeNumber: 1))
        let snapshot = WatchedSeason(showTmdbID: 42, seasonNumber: 1, showName: "Probe Show",
                                     seasonName: "Season 1", posterPath: nil, airDate: nil,
                                     episodeCount: 3)
        snapshot.userRating = 4.5
        context.insert(snapshot)
        let item = MediaItem(tmdbID: 42, mediaType: .tv, title: "Probe Show")
        item.showWatched = true
        context.insert(item)
        store.save()
        return store
    }

    @Test func openingAShowMidImportKeepsTheSyncedSeason() {
        let store = partiallyImported()
        let show = makeShow()

        store.reconcileSeasons(for: show)
        store.reconcileMembership(show)

        #expect(WatchedSeason.find(showTmdbID: 42, seasonNumber: 1, in: store.context) != nil)
        #expect(store.seasonRating(showID: 42, season: 1) == 4.5)
    }

    @Test func openingAShowMidImportLeavesItFinished() {
        let store = partiallyImported()
        let show = makeShow()

        store.reconcileSeasons(for: show)
        store.reconcileMembership(show)

        #expect(store.showProgress(showID: 42).isWatched)
        #expect(!store.isInWatchList(showID: 42))                 // no bogus return to to-watch
        #expect(TrackedSeason.find(showTmdbID: 42, in: store.context) == nil)
    }

    // The one thing that disproves a snapshot without the user acting: TMDB adding an episode to a finished season.
    @Test func aSeasonThatOutgrewItsSnapshotLosesIt() {
        let store = partiallyImported()
        let grown = makeShow(episodeCount: 4)

        store.reconcileSeasons(for: grown)
        store.reconcileMembership(grown)

        #expect(WatchedSeason.find(showTmdbID: 42, seasonNumber: 1, in: store.context) == nil)
        #expect(!store.showProgress(showID: 42).isWatched)
        #expect(store.isInWatchList(showID: 42))
    }

    @Test func unwatchingAnEpisodeStillDropsTheSnapshot() {
        let store = makeInMemoryStore()
        let show = makeShow()
        store.setSeasonWatched(true, show: show, season: show.seasons[0])
        #expect(WatchedSeason.find(showTmdbID: 42, seasonNumber: 1, in: store.context) != nil)

        store.setEpisodeWatched(false, showID: 42, season: 1, episode: 2)
        store.reconcileSeasons(for: show, editedSeason: 1)
        store.reconcileMembership(show)

        #expect(WatchedSeason.find(showTmdbID: 42, seasonNumber: 1, in: store.context) == nil)
        #expect(!store.showProgress(showID: 42).isWatched)
        #expect(store.isInWatchList(showID: 42))
    }

    @Test func editingOneSeasonSparesTheOthers() {
        let store = partiallyImported()
        var show = makeShow()
        var second = Season(id: 200, seasonNumber: 2, name: "Season 2", episodeCount: 2)
        second.episodes = (1...2).map {
            Episode(id: 2000 + $0, seasonNumber: 2, episodeNumber: $0, name: "E\($0)")
        }
        show.seasons.append(second)

        store.reconcileSeasons(for: show, editedSeason: 2)

        #expect(WatchedSeason.find(showTmdbID: 42, seasonNumber: 1, in: store.context) != nil)
    }
}

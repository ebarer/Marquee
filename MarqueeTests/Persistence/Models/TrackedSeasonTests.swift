//
//  TrackedSeasonTests.swift
//  MarqueeTests
//
//  A show in every list except Watched is represented by its next-incomplete "tracked"
//  season. Watching an episode makes the show "to watch" (Watch List); completing a season
//  advances the tracked season; fully watching removes it.
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@MainActor
@Suite struct TrackedSeasonTests {
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

    @Test func watchingAnEpisodeAddsToWatchListAndTracksTheSeason() {
        let store = makeInMemoryStore()
        let show = makeShow(id: 1, seasons: [makeSeason(1, episodes: 3), makeSeason(2, episodes: 3)])

        store.toggleEpisodeWatched(show: show, season: show.seasons[0], episodeNumber: 1)

        #expect(store.isInWatchList(show))                                 // watching == to watch
        let tracked = TrackedSeason.find(showTmdbID: 1, in: store.context)
        #expect(tracked?.seasonNumber == 1)
        #expect(tracked?.episodeCount == 3)
    }

    @Test func bookmarkingAFreshShowTracksTheFirstSeason() {
        let store = makeInMemoryStore()
        let show = makeShow(id: 2, seasons: [makeSeason(1, episodes: 4), makeSeason(2, episodes: 4)])

        store.addToWatchList(show)
        store.reconcileMembership(show)

        let tracked = TrackedSeason.find(showTmdbID: 2, in: store.context)
        #expect(tracked?.seasonNumber == 1)
        #expect(tracked?.episodeCount == 4)
    }

    @Test func completingTheTrackedSeasonAdvancesToTheNext() {
        let store = makeInMemoryStore()
        let s1 = makeSeason(1, episodes: 2), s2 = makeSeason(2, episodes: 2)
        let show = makeShow(id: 3, seasons: [s1, s2])

        store.setSeasonWatched(true, show: show, season: s1)

        #expect(WatchedSeason.find(showTmdbID: 3, seasonNumber: 1, in: store.context) != nil) // S1 completed
        let tracked = TrackedSeason.find(showTmdbID: 3, in: store.context)
        #expect(tracked?.seasonNumber == 2)                                                   // now tracking S2
        #expect(store.isInWatchList(show))
    }

    @Test func fullyWatchingRemovesFromWatchListAndDeletesTracked() async {
        let store = makeInMemoryStore()
        let show = makeShow(id: 4, seasons: [makeSeason(1, episodes: 2), makeSeason(2, episodes: 2)])
        store.addToWatchList(show)

        await store.setShowWatched(true, show: show)

        #expect(store.isShowFullyWatched(show))
        #expect(!store.isInWatchList(show))
        #expect(TrackedSeason.find(showTmdbID: 4, in: store.context) == nil)
    }

    @Test func unwatchingBelowCompleteReturnsShowToTheWatchList() async {
        let store = makeInMemoryStore()
        let season = makeSeason(1, episodes: 2)
        let show = makeShow(id: 5, seasons: [season])
        await store.setShowWatched(true, show: show)
        #expect(!store.isInWatchList(show))

        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 1)   // 1/2 — in progress again

        #expect(store.isInWatchList(show))
        #expect(TrackedSeason.find(showTmdbID: 5, in: store.context)?.seasonNumber == 1)
    }

    @Test func nextEpisodeDateIsFirstUnwatchedEpisodesAirDate() {
        let store = makeInMemoryStore()
        var season = Season(id: 100, seasonNumber: 1, name: "Season 1", episodeCount: 3)
        season.episodes = [
            episode(1, .utc(2024, 1, 1)),
            episode(2, .utc(2024, 1, 8)),
            episode(3, .utc(2024, 1, 15)),
        ]
        let show = makeShow(id: 6, seasons: [season])

        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 1)   // next unwatched = E2

        let tracked = TrackedSeason.find(showTmdbID: 6, in: store.context)
        #expect(tracked?.nextEpisodeDate == .utc(2024, 1, 8))
    }

    @Test func deduplicateCollapsesTrackedSeasons() {
        let store = makeInMemoryStore()
        store.context.insert(TrackedSeason(showTmdbID: 9, seasonNumber: 1, showName: "X",
                                           posterPath: nil, episodeCount: 3))
        store.context.insert(TrackedSeason(showTmdbID: 9, seasonNumber: 1, showName: "X",
                                           posterPath: nil, episodeCount: 3))
        store.save()

        TrackedSeason.deduplicate(in: store.context)

        #expect(TrackedSeason.all(in: store.context).filter { $0.showTmdbID == 9 }.count == 1)
    }

    @Test func listSectionRendersTrackedShowAsASeason() async {
        let store = makeInMemoryStore()
        let show = makeShow(id: 30, seasons: [makeSeason(1, episodes: 3, airStart: .utc(2024, 6, 1))])
        store.addToWatchList(show)
        store.reconcileMembership(show)

        let uuid = store.watchList.uuid
        let sections = await store.sections(for: .list(uuid, byDateAdded: false, foldOlder: false),
                                            ascending: false, filter: "")
        let rows = sections.flatMap(\.entries)
        #expect(rows.contains { $0.tmdbID == 30 && $0.seasonNumber == 1 && $0.seasonTotal == 3 })
    }

    @Test func customListRendersTrackedShowAsWholeShow() async {
        let store = makeInMemoryStore()
        let show = makeShow(id: 31, seasons: [makeSeason(1, episodes: 3, airStart: .utc(2024, 6, 1))])
        let list = MediaList(name: "Favorites", symbol: "heart", sortOrder: 1, colorIndex: 2)
        store.context.insert(list)
        store.add(show, to: list)
        store.reconcileMembership(show)   // a TrackedSeason exists (show is on a list)…

        let sections = await store.sections(for: .list(list.uuid, byDateAdded: false, foldOlder: false),
                                            ascending: false, filter: "")
        let rows = sections.flatMap(\.entries)
        // …but a custom list shows the whole show, never a season.
        #expect(rows.contains { $0.tmdbID == 31 && $0.seasonNumber == nil })
        #expect(!rows.contains { $0.tmdbID == 31 && $0.seasonNumber != nil })
    }

    @Test func caughtUpWithUnairedSeasonReadsAsWatchedAndReturnsWhenItAirs() {
        let store = makeInMemoryStore()
        let s1 = makeSeason(1, episodes: 2)
        let s2Upcoming = Season(id: 200, seasonNumber: 2, name: "Season 2", episodeCount: 0) // unaired
        let show = makeShow(id: 40, seasons: [s1, s2Upcoming])

        store.setSeasonWatched(true, show: show, season: s1)                 // caught up

        #expect(store.isShowFullyWatched(show))                             // checkmark filled
        #expect(!store.isInWatchList(show))                                 // off the Watch List
        #expect(TrackedSeason.find(showTmdbID: 40, in: store.context) == nil)

        // Season 2 airs: same show id, S2 now has episodes.
        var s2Aired = Season(id: 200, seasonNumber: 2, name: "Season 2", episodeCount: 2)
        s2Aired.episodes = (1...2).map { Episode(id: 2000 + $0, seasonNumber: 2, episodeNumber: $0, name: "E\($0)") }
        let aired = makeShow(id: 40, seasons: [s1, s2Aired])

        store.reconcileMembership(aired)                                    // detail reopens after airing

        #expect(!store.isShowFullyWatched(aired))
        #expect(store.isInWatchList(aired))                                 // back on the Watch List
        #expect(TrackedSeason.find(showTmdbID: 40, in: store.context)?.seasonNumber == 2)
    }

    @Test func seasonWatchedDateIsEditableAndSurvivesReconcile() {
        let store = makeInMemoryStore()
        let season = makeSeason(1, episodes: 2, airStart: .utc(2024, 1, 1))
        let show = makeShow(id: 50, seasons: [season])
        store.setSeasonWatched(true, show: show, season: season)
        #expect(store.seasonWatchedDate(showID: 50, season: 1) != nil)

        let edited = Date.utc(2023, 5, 20)
        store.setSeasonWatchedDate(edited, showID: 50, season: 1)
        #expect(store.seasonWatchedDate(showID: 50, season: 1) == edited)

        store.reconcileSeasons(for: show)                                   // must not clobber the edit
        #expect(store.seasonWatchedDate(showID: 50, season: 1) == edited)
    }

    @Test func watchedShowIDsAreDistinctInProgressShows() {
        let store = makeInMemoryStore()
        let a = makeShow(id: 60, seasons: [makeSeason(1, episodes: 3)])
        let b = makeShow(id: 61, seasons: [makeSeason(1, episodes: 2)])
        store.toggleEpisodeWatched(show: a, season: a.seasons[0], episodeNumber: 1)
        store.toggleEpisodeWatched(show: a, season: a.seasons[0], episodeNumber: 2)  // same show twice
        store.toggleEpisodeWatched(show: b, season: b.seasons[0], episodeNumber: 1)

        #expect(Set(store.watchedShowIDs()) == [60, 61])
    }

    // MARK: - Marking stops at today

    /// A season part-way through airing: E1/E2 out, E3 still to come.
    private func airingSeason() -> Season {
        var season = Season(id: 700, seasonNumber: 1, name: "Season 1", episodeCount: 3)
        season.airDate = .utc(2024, 1, 1)
        season.episodes = [episode(1, .utc(2024, 1, 1)),
                           episode(2, .utc(2024, 1, 8)),
                           episode(3, .utc(2999, 1, 1))]
        return season
    }

    @Test func markingAShowWatchedSkipsEpisodesThatHaventAired() async {
        let store = makeInMemoryStore()
        let show = makeShow(id: 70, seasons: [airingSeason()])

        await store.setShowWatched(true, show: show)

        #expect(store.watchedEpisodeNumbers(showID: 70, season: 1) == [1, 2])   // E3 is in the future
        #expect(!store.isShowFullyWatched(show))                               // season isn't complete
        #expect(store.isInWatchList(show))                                     // so it stays to-watch
        #expect(TrackedSeason.find(showTmdbID: 70, in: store.context)?.nextEpisodeDate == .utc(2999, 1, 1))
    }

    @Test func markingASeasonWatchedSkipsEpisodesThatHaventAired() {
        let season = airingSeason()
        let store = makeInMemoryStore()
        let show = makeShow(id: 71, seasons: [season])

        store.setSeasonWatched(true, show: show, season: season)

        #expect(store.watchedEpisodeNumbers(showID: 71, season: 1) == [1, 2])
        #expect(WatchedSeason.find(showTmdbID: 71, seasonNumber: 1, in: store.context) == nil)
    }

    @Test func caughtUpReadsAsCaughtUpUntilAnEpisodeIsUnwatched() async {
        let season = airingSeason()
        let store = makeInMemoryStore()
        let show = makeShow(id: 72, seasons: [season])

        await store.setShowWatched(true, show: show)
        #expect(store.isShowCaughtUp(show))

        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: 2)   // back to 1/2 aired
        #expect(!store.isShowCaughtUp(show))
    }

    @Test func unmarkingAShowClearsEveryEpisodeRecord() async {
        let store = makeInMemoryStore()
        let show = makeShow(id: 73, seasons: [airingSeason()])
        await store.setShowWatched(true, show: show)

        await store.setShowWatched(false, show: show)

        #expect(store.watchedEpisodeNumbers(showID: 73, season: 1).isEmpty)
    }

    private func episode(_ number: Int, _ airDate: Date) -> Episode {
        var e = Episode(id: 1000 + number, seasonNumber: 1, episodeNumber: number, name: "E\(number)")
        e.airDate = airDate
        return e
    }
}

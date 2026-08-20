//
//  FrameBudgetTests.swift
//  MarqueeTests
//
//  Guards the rule that interactions stay at full frame rate. Unlike the `measure()` benchmarks
//  in PerformanceTests, every check here FAILS on regression. Bounds are deliberately loose —
//  they catch a change in kind (a fetch back in `body`, work back on the main actor), not drift.
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

/// Records the longest gap between ticks on the main actor.
@MainActor
private final class StallProbe {
    private var last = ContinuousClock.now
    private(set) var worst = Duration.zero

    func tick() {
        let now = ContinuousClock.now
        worst = max(worst, now - last)
        last = now
    }
}

// Serialized: the stall probe measures main-actor responsiveness, which other tests running in
// parallel would spoil.
@MainActor
@Suite(.serialized) struct FrameBudgetTests {

    // MARK: - Harness

    private func fastest(_ runs: Int = 7, _ body: () -> Void) -> Duration {
        (0..<runs).map { _ in ContinuousClock().measure(body) }.min() ?? .zero
    }

    // A dropped frame is exactly this exceeding the display interval, so it is the honest measure.
    private func mainActorStall(during work: () async -> Void) async -> Duration {
        let probe = StallProbe()
        let ticker = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1))
                probe.tick()
            }
        }
        await work()
        probe.tick()
        ticker.cancel()
        return probe.worst
    }

    // One frame at 60Hz. Anything the main actor does during an interaction has to fit inside it.
    private let frame = Duration.milliseconds(16)

    // MARK: - Fixtures

    private func badgeLibrary() -> PersistenceCoordinator {
        let store = makeInMemoryStore()
        for index in 1...800 { store.setWatched(true, for: makeMovie(id: index)) }
        for index in 801...1200 { store.addToWatchList(makeMovie(id: index)) }
        for show in 1...200 {
            store.context.insert(WatchedEpisode(showTmdbID: show, seasonNumber: 1, episodeNumber: 1))
        }
        store.save()
        return store
    }

    private func bigList() -> (PersistenceCoordinator, UUID) {
        let store = makeInMemoryStore()
        let list = MediaList(name: "Big")
        store.context.insert(list)
        var day = Date.utc(2000, 1, 1)
        for index in 1...3000 {
            var movie = makeMovie(id: index, title: "Movie \(index)")
            movie.releaseDate = day
            let entry = ListEntry(movie: movie)
            entry.list = list
            store.context.insert(entry)
            day = Calendar.current.date(byAdding: .day, value: 3, to: day)!
        }
        store.save()
        return (store, list.uuid)
    }

    private func makeShow(id: Int = 1, seasons: Int, episodes: Int = 10) -> Show {
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

    // MARK: - No SwiftData in a row or card body

    @Test func aScreenfulOfBadgesCostsNoFetches() {
        let store = badgeLibrary()
        let onScreen = Array(1...200)
        _ = store.badges                                  // prime, as the first rendered frame does

        let elapsed = fastest {
            let badges = store.badges
            for id in onScreen { _ = PosterStatus.derive(movieID: id, from: badges) }
        }

        // Set lookups land near 25µs; the per-title fetches this replaced took 25ms.
        #expect(elapsed < Duration.milliseconds(2),
                "Badge derivation regressed to per-title store lookups (\(elapsed))")
    }

    @Test func showBadgesCostNoFetchesEither() {
        let store = badgeLibrary()
        let onScreen = Array(1...200)
        _ = store.badges

        let elapsed = fastest {
            let badges = store.badges
            for id in onScreen { _ = PosterStatus.derive(showID: id, from: badges) }
        }

        #expect(elapsed < Duration.milliseconds(2),
                "Show badge derivation regressed to per-title store lookups (\(elapsed))")
    }

    // MARK: - Show controls read persisted state, not the payload

    @Test func showProgressDoesNotScaleWithSeasonCount() async {
        let store = makeInMemoryStore()
        let show = makeShow(seasons: 20)
        await store.setShowWatched(true, show: show)

        let elapsed = fastest { _ = store.showProgress(showID: show.id) }

        // Deriving this from `regularSeasons` ran a fetch per season, twice over.
        #expect(elapsed < Duration.milliseconds(3),
                "showProgress regressed to per-season episode fetches (\(elapsed))")
    }

    // The bug this replaced: a stub with no seasons read as unwatched until detail loaded.
    @Test func showProgressIsRightBeforeThePayloadLoads() async {
        let store = makeInMemoryStore()
        let show = makeShow(seasons: 3)
        await store.setShowWatched(true, show: show)

        #expect(store.showProgress(showID: show.id).isWatched)
        #expect(store.isShowWatchedCached(showID: show.id))
        // What the screen actually has on entry: an id and a name.
        #expect(store.showProgress(showID: Show(id: show.id, name: show.name).id).isWatched)
    }

    @Test func theStallProbeReadsZeroWhenNothingBlocks() async {
        let idle = await mainActorStall { try? await Task.sleep(for: .milliseconds(200)) }
        #expect(idle < Duration.milliseconds(5), "idle baseline is \(idle)")
    }

    // The load-bearing assumption behind moving fetching, formatting and the badge rebuild off main.
    @Test func theListReaderIsNotOnTheMainThread() async {
        let store = makeInMemoryStore()
        #expect(await store.listReadRunsOnMainThread() == false,
                "Lists reads are back on the main thread — did ListCoordinator become a @ModelActor again?")
    }

    // MARK: - Nothing heavy on the main actor

    @Test func buildingAListLeavesTheMainActorFree() async {
        let (store, listID) = bigList()
        let request = ListRequest.list(listID, sort: .releaseDate, foldOlder: [])
        // Warm the store, so this measures a rebuild rather than first-touch setup.
        _ = await store.sections(for: request, ascending: false, filter: "")

        let stall = await mainActorStall {
            _ = await store.sections(for: request, ascending: false, filter: "")
        }

        // Fetching and formatting both belong to ListCoordinator; on the main actor, sorting and
        // grouping 3000 rows alone would blow this.
        #expect(stall < frame,
                "Building a list blocked the main actor for \(stall) — formatting moved back on?")
    }

    @Test func savingLeavesTheMainActorFree() async {
        let store = badgeLibrary()
        _ = store.badges                                  // prime, so a save triggers a refresh
        store.setWatched(true, for: makeMovie(id: 9998))   // warm the write path
        try? await Task.sleep(for: .milliseconds(120))

        let stall = await mainActorStall {
            store.setWatched(true, for: makeMovie(id: 9999))
            // Let the badge refresh land, so a main-actor rebuild would show up here.
            try? await Task.sleep(for: .milliseconds(120))
        }

        #expect(stall < frame,
                "A save blocked the main actor for \(stall) — is the badge index rebuilding on it?")
    }
}

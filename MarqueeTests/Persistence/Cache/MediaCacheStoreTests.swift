//
//  MediaCacheStoreTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftUI
@testable import Marquee

@Suite(.serialized) struct MediaCacheStoreTests {
    private let cache = MediaCacheStore.shared

    @Test func saveThenLoadRoundTrips() async {
        await cache.clear()
        var movie = makeMovie(id: 5001, title: "Cached", poster: "/c.jpg")
        movie.overview = "Hi"
        await cache.save(movie, tint: .red)

        let loaded = await cache.load(id: 5001)
        #expect(loaded?.movie.id == 5001)
        #expect(loaded?.movie.overview == "Hi")
        #expect(loaded?.color != nil)
    }

    @Test func loadMissReturnsNil() async {
        await cache.clear()
        #expect(await cache.load(id: 999999) == nil)
    }

    @Test func freshnessGate() async {
        await cache.clear()
        await cache.save(makeMovie(id: 5002), tint: nil)
        #expect(await cache.isFresh(id: 5002, ttl: 3600))
        #expect(await cache.isFresh(id: 5002, ttl: 0) == false)
        #expect(await cache.isFresh(id: 424242, ttl: 3600) == false)
    }

    @Test func usageAndClear() async {
        await cache.clear()
        await cache.save(makeMovie(id: 5003), tint: nil)
        await cache.save(makeMovie(id: 5004), tint: nil)
        let usage = await cache.usage()
        #expect(usage.count == 2)
        #expect(usage.bytes > 0)

        await cache.clear()
        #expect(await cache.usage().count == 0)
    }

    // MARK: - Priority

    private func makeBoundedStore(_ name: String, maxEntries: Int) -> MediaCacheStore {
        MediaCacheStore(directoryName: "MediaCacheTests-\(name)", maxEntries: maxEntries)
    }

    @Test func evictionDropsTheWorstTierEvenWhenItIsNewest() async {
        let store = makeBoundedStore("tier", maxEntries: 2)
        await store.clear()
        await store.save(makeMovie(id: 1), tint: nil, priority: .watchList)
        await store.save(makeMovie(id: 2), tint: nil, priority: .discovery)
        await store.save(makeMovie(id: 3), tint: nil, priority: .watched)

        #expect(await store.load(id: 3) == nil)
        #expect(await store.load(id: 1) != nil)
        #expect(await store.load(id: 2) != nil)
        await store.clear()
    }

    @Test func evictionBreaksTiesWithinATierOnAge() async {
        let store = makeBoundedStore("age", maxEntries: 2)
        await store.clear()
        for id in 1...3 {
            await store.save(makeMovie(id: id), tint: nil, priority: .discovery)
            try? await Task.sleep(for: .milliseconds(50))
        }
        #expect(await store.load(id: 1) == nil)
        #expect(await store.load(id: 3) != nil)
        await store.clear()
    }

    @Test func savingAgainCannotDemoteATier() async {
        let store = makeBoundedStore("demote", maxEntries: 10)
        await store.clear()
        await store.save(makeMovie(id: 1), tint: nil, priority: .watchList)
        // An on-demand view of a Watch List title mustn't cost it its tier.
        await store.save(makeMovie(id: 1), tint: nil)
        #expect(await store.priority(id: 1) == .watchList)
        await store.clear()
    }

    @Test func applyPrioritiesRetagsAgainstThePlan() async {
        let store = makeBoundedStore("retag", maxEntries: 10)
        await store.clear()
        await store.save(makeMovie(id: 1), tint: nil, priority: .watchList)
        await store.save(makeMovie(id: 2), tint: nil, priority: .watchList)

        await store.applyPriorities([
            MediaCacheTarget(tmdbID: 2, mediaType: .movie, priority: .customList)
        ])
        // Off the plan, having left the Watch List, so it no longer holds its old tier.
        #expect(await store.priority(id: 1) == .browsed)
        #expect(await store.priority(id: 2) == .customList)
        await store.clear()
    }

    // MARK: - Season freshness

    private func makeShowWithSeason(id: Int, seasonNumber: Int = 1) -> (Show, Season) {
        var season = Season(id: seasonNumber * 100, seasonNumber: seasonNumber,
                            name: "Season \(seasonNumber)", episodeCount: 2)
        season.episodes = (1...2).map {
            Episode(id: seasonNumber * 1000 + $0, seasonNumber: seasonNumber,
                    episodeNumber: $0, name: "E\($0)")
        }
        var show = Show(id: id, name: "Show \(id)")
        show.seasons = [season]
        return (show, season)
    }

    @Test func aSeasonIsStaleUntilItIsCachedAndOnceItsTTLPasses() async {
        let store = MediaCacheStore(directoryName: "MediaCacheTests-season", maxEntries: 10)
        await store.clear()
        let (show, season) = makeShowWithSeason(id: 8)
        await store.save(show, tint: nil)
        // Cached with the show's season list, but the season itself was never fetched.
        #expect(await store.isSeasonFresh(showID: 8, seasonNumber: 1, ttl: 3600) == false)

        await store.cacheSeason(showID: 8, season)
        #expect(await store.isSeasonFresh(showID: 8, seasonNumber: 1, ttl: 3600))
        #expect(await store.isSeasonFresh(showID: 8, seasonNumber: 1, ttl: 0) == false)
        #expect(await store.isSeasonFresh(showID: 8, seasonNumber: 2, ttl: 3600) == false)
        await store.clear()
    }

    @Test func refreshingTheShowKeepsItsSeasonStamps() async {
        let store = MediaCacheStore(directoryName: "MediaCacheTests-stamps", maxEntries: 10)
        await store.clear()
        let (show, season) = makeShowWithSeason(id: 9)
        await store.save(show, tint: nil)
        await store.cacheSeason(showID: 9, season)

        // A show refresh carries cached episodes forward, so it must carry their stamps too.
        await store.save(show, tint: nil)
        #expect(await store.isSeasonFresh(showID: 9, seasonNumber: 1, ttl: 3600))
        await store.clear()
    }

    @Test func anEntryStampedByAnotherSchemaVersionReadsAsAMiss() async {
        let name = "MediaCacheTests-version"
        let store = MediaCacheStore(directoryName: name, maxEntries: 10)
        await store.clear()
        await store.save(makeMovie(id: 7), tint: nil)
        #expect(await store.load(id: 7) != nil)

        // Rewrite the entry the way a release before the stamp existed would have.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let unstamped = CachedMedia(movie: makeMovie(id: 7), tint: nil, cachedAt: Date())
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent("media-7.json")
        try? encoder.encode(unstamped).write(to: url, options: .atomic)

        #expect(await store.load(id: 7) == nil)
        await store.clear()
    }

    @Test func cachedMediaColorRequiresFourComponents() {
        let ok = CachedMedia(movie: makeMovie(id: 1), tint: [0.1, 0.2, 0.3, 1.0], cachedAt: Date())
        #expect(ok.color != nil)
        let bad = CachedMedia(movie: makeMovie(id: 1), tint: [0.1, 0.2], cachedAt: Date())
        #expect(bad.color == nil)
        let none = CachedMedia(movie: makeMovie(id: 1), tint: nil, cachedAt: Date())
        #expect(none.color == nil)
    }
}

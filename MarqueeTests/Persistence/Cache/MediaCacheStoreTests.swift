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

    @Test func cachedMediaColorRequiresFourComponents() {
        let ok = CachedMedia(movie: makeMovie(id: 1), tint: [0.1, 0.2, 0.3, 1.0], cachedAt: Date())
        #expect(ok.color != nil)
        let bad = CachedMedia(movie: makeMovie(id: 1), tint: [0.1, 0.2], cachedAt: Date())
        #expect(bad.color == nil)
        let none = CachedMedia(movie: makeMovie(id: 1), tint: nil, cachedAt: Date())
        #expect(none.color == nil)
    }
}

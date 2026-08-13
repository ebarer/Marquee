//
//  ShowPersistenceTests.swift
//  MarqueeTests
//
//  Show-level persistence via the MediaKey generalization (no schema change):
//  shows reuse MediaItem/ListEntry/MediaList with mediaType == .tv.
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@MainActor
@Suite struct ShowPersistenceTests {
    private func makeShow(id: Int, name: String = "Show") -> Show {
        var show = Show(id: id, name: name)
        show.firstAirDate = .utc(2020, 1, 1)
        return show
    }

    @Test func setWatchedCreatesTVMediaItem() {
        let store = makeInMemoryStore()
        let show = makeShow(id: 100)
        store.setWatched(true, for: show)
        #expect(store.isWatched(show))
        #expect(MediaItem.find(key: show.mediaKey, in: store.context)?.mediaType == .tv)
    }

    @Test func movieAndShowSharingTmdbIDStayDistinct() {
        let store = makeInMemoryStore()
        store.setWatched(true, for: makeMovie(id: 42))
        store.setRating(4.0, for: makeShow(id: 42))
        #expect(store.isWatched(makeMovie(id: 42)))
        #expect(!store.isWatched(makeShow(id: 42)))
        #expect(store.rating(for: makeShow(id: 42)) == 4.0)
        #expect(store.rating(for: makeMovie(id: 42)) == nil)
    }

    @Test func addShowToCustomListStoresTVEntry() {
        let store = makeInMemoryStore()
        let list = MediaList(name: "Sci-Fi", symbol: "star", sortOrder: 1)
        store.context.insert(list)
        let show = makeShow(id: 7)
        store.add(show, to: list)
        #expect(list.contains(show.id, .tv))
        #expect(list.entry(for: show.id, .tv)?.mediaType == .tv)
        // A movie with the same id is not considered a member.
        #expect(!list.contains(show.id, .movie))
    }

    @Test func watchListAddThenToggleRemovesShow() {
        let store = makeInMemoryStore()
        let show = makeShow(id: 9)
        store.addToWatchList(show)
        #expect(store.isInWatchList(show))
        store.toggleWatchList(show)
        #expect(!store.isInWatchList(show))
    }

    @Test func markingShowWatchedRemovesItFromWatchList() {
        let store = makeInMemoryStore()
        let show = makeShow(id: 11)
        store.addToWatchList(show)
        store.setWatched(true, for: show)
        #expect(!store.isInWatchList(show))
        #expect(store.isWatched(show))
    }

    @Test func showListEntryAnchorsOnMostRecentAirDate() {
        let store = makeInMemoryStore()
        let list = MediaList(name: "L", symbol: "star", sortOrder: 1)
        store.context.insert(list)
        var show = makeShow(id: 20)        // firstAirDate 2020-01-01
        show.lastAirDate = .utc(2026, 6, 1)
        store.add(show, to: list)
        let entry = list.entry(for: 20, .tv)
        #expect(entry?.sortDate == .utc(2026, 6, 1))     // timeline anchor = latest air
        #expect(entry?.releaseDate == .utc(2020, 1, 1))  // premiere preserved for display
    }

    @Test func movieListEntryHasNoSortDate() {
        let store = makeInMemoryStore()
        let list = MediaList(name: "L", symbol: "star", sortOrder: 1)
        store.context.insert(list)
        store.add(makeMovie(id: 21, release: .utc(2020, 1, 1)), to: list)
        #expect(list.entry(for: 21, .movie)?.sortDate == nil)
    }

    @Test func refreshSnapshotBackfillsSortDateFromDetail() {
        let store = makeInMemoryStore()
        let list = MediaList(name: "L", symbol: "star", sortOrder: 1)
        store.context.insert(list)
        // Search-added show: only the premiere is known.
        var lite = Show(id: 22, name: "Lite")
        lite.firstAirDate = .utc(2019, 1, 1)
        store.add(lite, to: list)
        #expect(list.entry(for: 22, .tv)?.sortDate == .utc(2019, 1, 1))
        // Detail arrives with the most-recent air date.
        var full = lite
        full.lastAirDate = .utc(2026, 6, 1)
        store.refreshSnapshot(for: full)
        #expect(list.entry(for: 22, .tv)?.sortDate == .utc(2026, 6, 1))
    }
}

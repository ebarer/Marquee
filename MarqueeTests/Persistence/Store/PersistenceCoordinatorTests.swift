//
//  PersistenceCoordinatorTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@MainActor
@Suite struct PersistenceCoordinatorTests {
    let store = makeInMemoryStore()

    @Test func watchListLazilyCreatedOnce() {
        let created = store.watchList
        let reused = store.watchList
        #expect(created === reused)
        #expect(store.lists.contains { $0 === created })
    }

    @Test func isInWatchListNeverCreatesTheList() {
        #expect(store.isInWatchList(makeMovie(id: 1)) == false)
        // Reading membership must not seed a Watch List.
        #expect(MediaList.watchList(in: store.context) == nil)
    }

    @Test func membershipWritesPersistAndBumpRevision() {
        let before = store.revision
        let movie = makeMovie(id: 1)
        store.addToWatchList(movie)
        #expect(store.isInWatchList(movie))
        #expect(store.revision > before)
    }

    @Test func toggleWatchListRoundTrips() {
        let movie = makeMovie(id: 1)
        store.toggleWatchList(movie)
        #expect(store.isInWatchList(movie))
        store.toggleWatchList(movie)
        #expect(store.isInWatchList(movie) == false)
    }

    @Test func factReadsAndWrites() {
        let movie = makeMovie(id: 1)
        store.setRating(3.5, for: movie)
        store.setWatched(true, for: movie)
        #expect(store.rating(for: movie) == 3.5)
        #expect(store.isWatched(movie))
        #expect(store.dateWatched(for: movie) != nil)
    }

    @Test func watchedAndViewedCounts() {
        store.setWatched(true, for: makeMovie(id: 1))
        store.setWatched(true, for: makeMovie(id: 2))
        store.recordView(makeMovie(id: 3))
        #expect(store.watchedCount == 2)
        #expect(store.viewedCount == 1)
    }

    @Test func clearViewedRemovesViewOnlyItems() {
        let watched = makeMovie(id: 1)
        store.setWatched(true, for: watched)
        store.recordView(watched)          // watched + viewed
        store.recordView(makeMovie(id: 2)) // viewed only
        store.clearViewed()
        #expect(store.viewedCount == 0)
        #expect(store.isWatched(watched))            // survives
        #expect(store.watchedCount == 1)
    }

    @Test func unwatchByModelPrunesEmpty() {
        let movie = makeMovie(id: 1)
        store.setWatched(true, for: movie)
        let item = MediaItem.find(movie, in: store.context)!
        store.unwatch(item)
        #expect(store.isWatched(movie) == false)
        #expect(MediaItem.find(movie, in: store.context) == nil)
    }

    @Test func deleteListRemovesItAndCascadesEntries() {
        let list = MediaList(name: "Temp")
        store.insert(list)
        store.add(makeMovie(id: 1), to: list)
        store.deleteList(list)
        #expect(store.customLists.isEmpty)
        let entries = (try? store.context.fetch(FetchDescriptor<ListEntry>())) ?? []
        #expect(entries.isEmpty)
    }

    @Test func canonicalListsCollapsesDuplicateWatchLists() {
        let older = MediaList(name: "Watch List", isWatchList: true)
        older.createdAt = .utc(2020, 1, 1)
        let newer = MediaList(name: "Watch List", isWatchList: true)
        newer.createdAt = .utc(2021, 1, 1)
        let hidden = MediaList(name: "Ghost", isWatchList: true)
        hidden.deduplicatedDate = Date()
        let result = store.canonicalLists([older, newer, hidden])
        #expect(result.contains { $0 === older })
        #expect(result.contains { $0 === newer } == false)
        #expect(result.contains { $0 === hidden } == false)
    }

    @Test func seedWatchListCreatesTheList() {
        store.seedWatchList()
        #expect(MediaList.watchList(in: store.context) != nil)
    }

    @Test func deduplicateConvergesDuplicates() {
        let ctx = store.context
        ctx.insert(MediaItem(tmdbID: 1, title: "A"))
        ctx.insert(MediaItem(tmdbID: 1, title: "A"))
        store.deduplicate()
        let items = (try? ctx.fetch(FetchDescriptor<MediaItem>())) ?? []
        #expect(items.filter { $0.tmdbID == 1 }.count == 1)
    }
}

//
//  MediaListTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftData
import SwiftUI
@testable import Marquee

@MainActor
@Suite struct MediaListTests {
    let store = makeInMemoryStore()
    var ctx: ModelContext { store.context }

    @Test func addIsIdempotent() {
        let list = MediaList(name: "Custom")
        ctx.insert(list)
        let movie = makeMovie(id: 1)
        list.add(movie)
        list.add(movie)
        #expect((list.entries ?? []).count == 1)
        #expect(list.contains(1))
    }

    @Test func toggleAddsThenRemoves() {
        let list = MediaList(name: "Custom")
        ctx.insert(list)
        let movie = makeMovie(id: 1)
        list.toggle(movie)
        #expect(list.contains(1))
        list.toggle(movie)
        try? ctx.save()  // reflect the entry delete in the to-many relationship
        #expect(list.contains(1) == false)
    }

    @Test func addWithoutContextDoesNothing() {
        let list = MediaList(name: "Detached")  // not inserted
        list.add(makeMovie(id: 1))
        #expect((list.entries ?? []).isEmpty)
    }

    @Test func addingToWatchListUnmarksWatched() {
        let movie = makeMovie(id: 1)
        MediaItem.setWatched(true, for: movie, in: ctx)
        let watch = MediaList.ensureWatchList(in: ctx)
        watch.add(movie)
        #expect(watch.contains(1))
        #expect(MediaItem.isWatched(movie, in: ctx) == false)
    }

    @Test func ensureWatchListIsCreatedOnceAndReused() {
        let a = MediaList.ensureWatchList(in: ctx)
        let b = MediaList.ensureWatchList(in: ctx)
        #expect(a === b)
        #expect(a.isWatchList)
        #expect(a.isEditable == false)
    }

    @Test func watchListPicksOldestCanonicalCopy() {
        let older = MediaList(name: "Watch List", isWatchList: true)
        older.createdAt = .utc(2020, 1, 1)
        let newer = MediaList(name: "Watch List", isWatchList: true)
        newer.createdAt = .utc(2021, 1, 1)
        ctx.insert(newer); ctx.insert(older)
        #expect(MediaList.watchList(in: ctx) === older)
    }

    @Test func allExcludesDeduplicatedAndDuplicateWatchLists() {
        let canonical = MediaList(name: "Watch List", isWatchList: true)
        canonical.createdAt = .utc(2020, 1, 1)
        let dupeWatch = MediaList(name: "Watch List", isWatchList: true)
        dupeWatch.createdAt = .utc(2021, 1, 1)
        let hidden = MediaList(name: "Ghost")
        hidden.deduplicatedDate = Date()
        let custom = MediaList(name: "Faves", sortOrder: 1)
        [canonical, dupeWatch, hidden, custom].forEach(ctx.insert)

        let all = MediaList.all(in: ctx)
        #expect(all.contains { $0 === canonical })
        #expect(all.contains { $0 === dupeWatch } == false)
        #expect(all.contains { $0 === hidden } == false)
        #expect(MediaList.customLists(in: ctx).map(\.name) == ["Faves"])
    }

    @Test func dedupeEntriesKeepsEarliest() {
        let list = MediaList(name: "Custom")
        ctx.insert(list)
        let a = ListEntry(movie: makeMovie(id: 1)); a.addedAt = .utc(2020, 1, 1); a.list = list
        let b = ListEntry(movie: makeMovie(id: 1)); b.addedAt = .utc(2021, 1, 1); b.list = list
        ctx.insert(a); ctx.insert(b)
        list.dedupeEntries()
        try? ctx.save()  // reflect the entry delete in the to-many relationship
        #expect((list.entries ?? []).count == 1)
        #expect(list.entry(for: 1) === a)
    }

    @Test func deduplicateWatchListMergesEntriesAndMarksDuplicate() {
        let keep = MediaList(name: "Watch List", isWatchList: true)
        keep.createdAt = .utc(2020, 1, 1)
        let dupe = MediaList(name: "Watch List", isWatchList: true)
        dupe.createdAt = .utc(2021, 1, 1)
        ctx.insert(keep); ctx.insert(dupe)
        let entry = ListEntry(movie: makeMovie(id: 1)); entry.list = dupe
        ctx.insert(entry)

        #expect(MediaList.deduplicateWatchList(in: ctx))
        #expect(keep.contains(1))            // re-parented onto winner
        #expect(dupe.isDeduplicated)         // marked, not yet deleted
        #expect(MediaList.all(in: ctx).filter(\.isWatchList).count == 1)
    }

    @Test func deduplicateWatchListPrunesEmptyMarkedPastGracePeriod() {
        let keep = MediaList(name: "Watch List", isWatchList: true)
        keep.createdAt = .utc(2020, 1, 1)
        let stale = MediaList(name: "Watch List", isWatchList: true)
        stale.createdAt = .utc(2021, 1, 1)
        stale.deduplicatedDate = Date(timeIntervalSinceNow: -120)  // past 30s grace
        ctx.insert(keep); ctx.insert(stale)

        #expect(MediaList.deduplicateWatchList(in: ctx))
        let all = (try? ctx.fetch(FetchDescriptor<MediaList>())) ?? []
        #expect(all.count == 1)
        #expect(all.first === keep)
    }

    @Test func colorPrefersWatchListAccentThenCustomHexThenPalette() {
        let watch = MediaList(name: "W", isWatchList: true)
        #expect(watch.color == .appAccent)

        let custom = MediaList(name: "C", colorIndex: 3)
        #expect(custom.color == Color.listColor(3))
        custom.customColorHex = "#112233"
        #expect(custom.color == Color(hex: "#112233"))
    }

    @Test func sortKeyBacksRawString() {
        let list = MediaList(name: "C")
        #expect(list.sortKey == .releaseDate)
        list.sortKey = .dateAdded
        #expect(list.sortKeyRaw == ListSortKey.dateAdded.rawValue)
    }
}

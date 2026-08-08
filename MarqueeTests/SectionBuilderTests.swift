//
//  SectionBuilderTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@MainActor
@Suite struct SectionBuilderTests {
    let store = makeInMemoryStore()

    private func builder() -> SectionBuilder {
        SectionBuilder(modelContainer: store.context.container)
    }

    /// Seeds a custom list with entries carrying explicit release/added dates.
    private func seedList(_ rows: [(id: Int, title: String, release: Date?, added: Date)],
                          isWatchList: Bool = false) -> UUID {
        let list = MediaList(name: isWatchList ? "Watch List" : "Custom", isWatchList: isWatchList)
        store.context.insert(list)
        for row in rows {
            var movie = makeMovie(id: row.id, title: row.title)
            movie.releaseDate = row.release
            let entry = ListEntry(movie: movie)
            entry.addedAt = row.added
            entry.list = list
            store.context.insert(entry)
        }
        store.save()
        return list.uuid
    }

    @Test func listGroupsByReleaseMonthAscending() async {
        let id = seedList([
            (1, "Jan", .utc(2020, 1, 15), .utc(2022, 1, 1)),
            (2, "Mar", .utc(2020, 3, 15), .utc(2022, 1, 2)),
            (3, "Jan2", .utc(2020, 1, 20), .utc(2022, 1, 3)),
        ])
        let sections = await builder().build(source: .list(id, byDateAdded: false, foldOlder: true),
                                             ascending: true, filter: "")
        #expect(sections.count == 2)
        #expect(sections.first?.entries.count == 2)   // two January titles
        #expect(sections.last?.entries.map(\.tmdbID) == [2])
    }

    @Test func listDescendingReversesSectionOrder() async {
        let id = seedList([
            (1, "Jan", .utc(2020, 1, 15), .utc(2022, 1, 1)),
            (2, "Mar", .utc(2020, 3, 15), .utc(2022, 1, 2)),
        ])
        let sections = await builder().build(source: .list(id, byDateAdded: false, foldOlder: true),
                                             ascending: false, filter: "")
        #expect(sections.first?.entries.map(\.tmdbID) == [2])  // March first
    }

    @Test func listByDateAddedIsFlatHeaderless() async {
        let id = seedList([
            (1, "A", nil, .utc(2022, 1, 1)),
            (2, "B", nil, .utc(2022, 6, 1)),
            (3, "C", nil, .utc(2022, 3, 1)),
        ])
        let sections = await builder().build(source: .list(id, byDateAdded: true, foldOlder: true),
                                             ascending: true, filter: "")
        #expect(sections.count == 1)
        #expect(sections[0].title.isEmpty)
        #expect(sections[0].entries.map(\.tmdbID) == [1, 3, 2])  // by addedAt asc
    }

    @Test func listFilterMatchesTitleCaseInsensitively() async {
        let id = seedList([
            (1, "The Matrix", .utc(2020, 1, 15), .utc(2022, 1, 1)),
            (2, "Inception", .utc(2020, 2, 15), .utc(2022, 1, 2)),
        ])
        let sections = await builder().build(source: .list(id, byDateAdded: false, foldOlder: true),
                                             ascending: true, filter: "matrix")
        #expect(sections.flatMap(\.entries).map(\.tmdbID) == [1])
    }

    @Test func emptyListYieldsNoSections() async {
        let id = seedList([])
        let sections = await builder().build(source: .list(id, byDateAdded: false, foldOlder: true),
                                             ascending: true, filter: "")
        #expect(sections.isEmpty)
    }

    /// Watch List rows: `recent` upcoming (distantFuture) titles + `old` archived
    /// (early-2000s) titles. Folds into "Older" only when both counts clear the
    /// thresholds (recent >= 3 && older >= 3).
    private func seedWatchList(recent: Int, old: Int) -> UUID {
        var rows: [(id: Int, title: String, release: Date?, added: Date)] = []
        for i in 0..<recent {
            rows.append((100 + i, "New\(i)", .distantFuture, .utc(2022, 1, i + 1)))
        }
        for i in 0..<old {
            rows.append((200 + i, "Old\(i)", .utc(2000 + i, 1, 15), .utc(2022, 2, i + 1)))
        }
        return seedList(rows, isWatchList: true)
    }

    @Test func watchListFoldsOlderWhenBothCountsClearThreshold() async {
        let id = seedWatchList(recent: 2, old: 3)
        let sections = await builder().build(source: .list(id, byDateAdded: false, foldOlder: true),
                                             ascending: false, filter: "")
        #expect(sections.contains { $0.isCollapsible })
        #expect(sections.last?.title == "Older")
        #expect(Set(sections.last?.entries.map(\.tmdbID) ?? []) == [200, 201, 202])
    }

    @Test func watchListStaysExpandedWhenEverythingIsOld() async {
        // No recent releases at all, so folding would hide the whole list behind a
        // collapsed "Older" bucket. Keep every title visible in its month section.
        let id = seedWatchList(recent: 0, old: 5)
        let sections = await builder().build(source: .list(id, byDateAdded: false, foldOlder: true),
                                             ascending: false, filter: "")
        #expect(!sections.contains { $0.isCollapsible })
        #expect(sections.flatMap(\.entries).count == 5)
    }

    @Test func watchListStaysExpandedWithTooFewRecent() async {
        // Only one upcoming title — not a big enough new-releases block to justify
        // tucking the backlog away; keep it all inline.
        let id = seedWatchList(recent: 1, old: 6)
        let sections = await builder().build(source: .list(id, byDateAdded: false, foldOlder: true),
                                             ascending: false, filter: "")
        #expect(!sections.contains { $0.isCollapsible })
        #expect(sections.flatMap(\.entries).count == 7)
    }

    @Test func watchListStaysExpandedWithTooSmallBacklog() async {
        // Plenty of upcoming titles but only two old ones — folding two rows into a
        // bucket saves nothing, so leave them visible.
        let id = seedWatchList(recent: 5, old: 2)
        let sections = await builder().build(source: .list(id, byDateAdded: false, foldOlder: true),
                                             ascending: false, filter: "")
        #expect(!sections.contains { $0.isCollapsible })
        #expect(sections.flatMap(\.entries).count == 7)
    }

    @Test func watchListKeepsAllMonthsWhenFoldDisabled() async {
        // Counts clear the thresholds, so only the toggle keeps it expanded.
        let id = seedWatchList(recent: 3, old: 3)
        let sections = await builder().build(source: .list(id, byDateAdded: false, foldOlder: false),
                                             ascending: false, filter: "")
        #expect(!sections.contains { $0.isCollapsible })
    }

    @Test func watchedGroupsByWatchedDateAndCarriesFacts() async {
        let a = makeMovie(id: 1, title: "A")
        let b = makeMovie(id: 2, title: "B")
        store.setWatched(true, for: a)
        store.setWatched(true, for: b)
        store.setRating(4, for: a)
        store.setDateWatched(.utc(2021, 5, 10), for: a)
        store.setDateWatched(.utc(2021, 8, 10), for: b)

        let sections = await builder().build(source: .watched(sort: .dateWatched),
                                             ascending: true, filter: "")
        #expect(sections.count == 2)
        let first = sections.first?.entries.first
        #expect(first?.tmdbID == 1)
        #expect(first?.dateWatched == .utc(2021, 5, 10))
        #expect(first?.userRating == 4)
    }

    @Test func watchedRatingSortGroupsByStars() async {
        let a = makeMovie(id: 1, title: "A")
        let b = makeMovie(id: 2, title: "B")
        let c = makeMovie(id: 3, title: "C")
        for m in [a, b, c] { store.setWatched(true, for: m) }
        store.setRating(5, for: a)
        store.setRating(4.5, for: b)
        // c left unrated

        let sections = await builder().build(source: .watched(sort: .rating),
                                             ascending: false, filter: "")
        #expect(sections.map(\.title) == ["5 Stars", "4.5 Stars", "Unrated"])
        #expect(sections.first?.entries.map(\.tmdbID) == [1])
        #expect(sections.last?.entries.map(\.tmdbID) == [3])
    }

    @Test func viewedIsFlatByRecency() async {
        for id in 1...3 { store.recordView(makeMovie(id: id, title: "M\(id)")) }
        let sections = await builder().build(source: .viewed, ascending: false, filter: "")
        #expect(sections.count == 1)
        #expect(sections[0].entries.count == 3)
        #expect(sections[0].entries.first?.tmdbID == 3)  // most recent first
    }
}

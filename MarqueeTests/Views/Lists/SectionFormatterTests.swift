//
//  SectionFormatterTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

/// Exercises the list pipeline end to end: `ListCoordinator` (fetch + dates + layout) piped
/// through `SectionFormatter` (grouping / "Older" fold / rating buckets).
@MainActor
@Suite struct SectionFormatterTests {
    let store = makeInMemoryStore()

    private func sections(_ request: ListRequest, ascending: Bool, filter: String = "",
                          mediaFilter: MediaTypeFilter = .all) async -> [SectionSnapshot] {
        let coordinator = ListCoordinator(modelContainer: store.context.container)
        let list = await coordinator.load(request: request, filter: filter, mediaFilter: mediaFilter)
        return SectionFormatter.sections(from: list, ascending: ascending)
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
        let result = await sections(.list(id, byDateAdded: false, foldOlder: true), ascending: true)
        #expect(result.count == 2)
        #expect(result.first?.entries.count == 2)   // two January titles
        #expect(result.last?.entries.map(\.tmdbID) == [2])
    }

    @Test func listDescendingReversesSectionOrder() async {
        let id = seedList([
            (1, "Jan", .utc(2020, 1, 15), .utc(2022, 1, 1)),
            (2, "Mar", .utc(2020, 3, 15), .utc(2022, 1, 2)),
        ])
        let result = await sections(.list(id, byDateAdded: false, foldOlder: true), ascending: false)
        #expect(result.first?.entries.map(\.tmdbID) == [2])  // March first
    }

    @Test func listByDateAddedIsFlatHeaderless() async {
        let id = seedList([
            (1, "A", nil, .utc(2022, 1, 1)),
            (2, "B", nil, .utc(2022, 6, 1)),
            (3, "C", nil, .utc(2022, 3, 1)),
        ])
        let result = await sections(.list(id, byDateAdded: true, foldOlder: true), ascending: true)
        #expect(result.count == 1)
        #expect(result[0].title.isEmpty)
        #expect(result[0].entries.map(\.tmdbID) == [1, 3, 2])  // by addedAt asc
    }

    @Test func listFilterMatchesTitleCaseInsensitively() async {
        let id = seedList([
            (1, "The Matrix", .utc(2020, 1, 15), .utc(2022, 1, 1)),
            (2, "Inception", .utc(2020, 2, 15), .utc(2022, 1, 2)),
        ])
        let result = await sections(.list(id, byDateAdded: false, foldOlder: true), ascending: true, filter: "matrix")
        #expect(result.flatMap(\.entries).map(\.tmdbID) == [1])
    }

    @Test func emptyListYieldsNoSections() async {
        let id = seedList([])
        let result = await sections(.list(id, byDateAdded: false, foldOlder: true), ascending: true)
        #expect(result.isEmpty)
    }

    /// Watch List rows: `recent` upcoming titles + `old` archived ones. Folds into "Older"
    /// only when both clear their thresholds (recent >= 3 && older >= 3).
    private func seedWatchList(recent: Int, old: Int) -> UUID {
        var rows: [(id: Int, title: String, release: Date?, added: Date)] = []
        for offset in 0..<recent {
            rows.append((100 + offset, "New\(offset)", .distantFuture, .utc(2022, 1, offset + 1)))
        }
        for offset in 0..<old {
            rows.append((200 + offset, "Old\(offset)", .utc(2000 + offset, 1, 15),
                         .utc(2022, 2, offset + 1)))
        }
        return seedList(rows, isWatchList: true)
    }

    @Test func watchListFoldsOlderWhenBothCountsClearThreshold() async {
        let id = seedWatchList(recent: 2, old: 3)
        let result = await sections(.list(id, byDateAdded: false, foldOlder: true), ascending: false)
        #expect(result.contains { $0.isCollapsible })
        #expect(result.last?.title == "Older")
        #expect(Set(result.last?.entries.map(\.tmdbID) ?? []) == [200, 201, 202])
    }

    @Test func watchListStaysExpandedWhenEverythingIsOld() async {
        // No recent releases at all, so folding would hide the whole list behind a
        // collapsed "Older" bucket. Keep every title visible in its month section.
        let id = seedWatchList(recent: 0, old: 5)
        let result = await sections(.list(id, byDateAdded: false, foldOlder: true), ascending: false)
        #expect(!result.contains { $0.isCollapsible })
        #expect(result.flatMap(\.entries).count == 5)
    }

    @Test func watchListStaysExpandedWithTooFewRecent() async {
        // Only one upcoming title — not a big enough new-releases block to justify
        // tucking the backlog away; keep it all inline.
        let id = seedWatchList(recent: 1, old: 6)
        let result = await sections(.list(id, byDateAdded: false, foldOlder: true), ascending: false)
        #expect(!result.contains { $0.isCollapsible })
        #expect(result.flatMap(\.entries).count == 7)
    }

    @Test func watchListStaysExpandedWithTooSmallBacklog() async {
        // Plenty of upcoming titles but only two old ones — folding two rows into a
        // bucket saves nothing, so leave them visible.
        let id = seedWatchList(recent: 5, old: 2)
        let result = await sections(.list(id, byDateAdded: false, foldOlder: true), ascending: false)
        #expect(!result.contains { $0.isCollapsible })
        #expect(result.flatMap(\.entries).count == 7)
    }

    @Test func watchListKeepsAllMonthsWhenFoldDisabled() async {
        // Counts clear the thresholds, so only the toggle keeps it expanded.
        let id = seedWatchList(recent: 3, old: 3)
        let result = await sections(.list(id, byDateAdded: false, foldOlder: false), ascending: false)
        #expect(!result.contains { $0.isCollapsible })
    }

    @Test func watchedGroupsByWatchedDateAndCarriesFacts() async {
        let earlier = makeMovie(id: 1, title: "A")
        let later = makeMovie(id: 2, title: "B")
        store.setWatched(true, for: earlier)
        store.setWatched(true, for: later)
        store.setRating(4, for: earlier)
        store.setDateWatched(.utc(2021, 5, 10), for: earlier)
        store.setDateWatched(.utc(2021, 8, 10), for: later)

        let result = await sections(.watched(sort: .dateWatched), ascending: true)
        #expect(result.count == 2)
        let first = result.first?.entries.first
        #expect(first?.tmdbID == 1)
        #expect(first?.dateWatched == .utc(2021, 5, 10))
        #expect(first?.userRating == 4)
    }

    @Test func watchedRatingSortGroupsByStars() async {
        let rated5 = makeMovie(id: 1, title: "A")
        let rated45 = makeMovie(id: 2, title: "B")
        let unrated = makeMovie(id: 3, title: "C")
        for movie in [rated5, rated45, unrated] { store.setWatched(true, for: movie) }
        store.setRating(5, for: rated5)
        store.setRating(4.5, for: rated45)
        // `unrated` left unrated

        let result = await sections(.watched(sort: .rating), ascending: false)
        #expect(result.map(\.title) == ["5 Stars", "4.5 Stars", "Unrated"])
        #expect(result.first?.entries.map(\.tmdbID) == [1])
        #expect(result.last?.entries.map(\.tmdbID) == [3])
    }

    @Test func viewedIsFlatByRecency() async {
        for id in 1...3 { store.recordView(makeMovie(id: id, title: "M\(id)")) }
        let result = await sections(.viewed, ascending: false)
        #expect(result.count == 1)
        #expect(result[0].entries.count == 3)
        #expect(result[0].entries.first?.tmdbID == 3)  // most recent first
    }
}

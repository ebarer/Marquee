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
    private func seedList(_ rows: [(id: Int, title: String, release: Date?, added: Date)]) -> UUID {
        let list = MediaList(name: "Custom")
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
        let sections = await builder().build(source: .list(id, byDateAdded: false),
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
        let sections = await builder().build(source: .list(id, byDateAdded: false),
                                             ascending: false, filter: "")
        #expect(sections.first?.entries.map(\.tmdbID) == [2])  // March first
    }

    @Test func listByDateAddedIsFlatHeaderless() async {
        let id = seedList([
            (1, "A", nil, .utc(2022, 1, 1)),
            (2, "B", nil, .utc(2022, 6, 1)),
            (3, "C", nil, .utc(2022, 3, 1)),
        ])
        let sections = await builder().build(source: .list(id, byDateAdded: true),
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
        let sections = await builder().build(source: .list(id, byDateAdded: false),
                                             ascending: true, filter: "matrix")
        #expect(sections.flatMap(\.entries).map(\.tmdbID) == [1])
    }

    @Test func emptyListYieldsNoSections() async {
        let id = seedList([])
        let sections = await builder().build(source: .list(id, byDateAdded: false),
                                             ascending: true, filter: "")
        #expect(sections.isEmpty)
    }

    @Test func watchedGroupsByWatchedDateAndCarriesFacts() async {
        let a = makeMovie(id: 1, title: "A")
        let b = makeMovie(id: 2, title: "B")
        store.setWatched(true, for: a)
        store.setWatched(true, for: b)
        store.setRating(4, for: a)
        store.setDateWatched(.utc(2021, 5, 10), for: a)
        store.setDateWatched(.utc(2021, 8, 10), for: b)

        let sections = await builder().build(source: .watched(byWatchedDate: true),
                                             ascending: true, filter: "")
        #expect(sections.count == 2)
        let first = sections.first?.entries.first
        #expect(first?.tmdbID == 1)
        #expect(first?.dateWatched == .utc(2021, 5, 10))
        #expect(first?.userRating == 4)
    }

    @Test func viewedIsFlatByRecency() async {
        for id in 1...3 { store.recordView(makeMovie(id: id, title: "M\(id)")) }
        let sections = await builder().build(source: .viewed, ascending: false, filter: "")
        #expect(sections.count == 1)
        #expect(sections[0].entries.count == 3)
        #expect(sections[0].entries.first?.tmdbID == 3)  // most recent first
    }
}

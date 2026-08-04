//
//  ListSectionsModelTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@MainActor
@Suite struct ListSectionsModelTests {
    private func input(source: SectionSource?, count: Int = 0, ascending: Bool = true,
                       filter: String = "", version: Int = 0) -> ListSectionsModel.Input {
        .init(source: source, count: count, ascending: ascending, filter: filter, version: version)
    }

    @Test func nilSourceClearsSections() async {
        let model = ListSectionsModel()
        await model.rebuild(for: input(source: nil), store: makeInMemoryStore())
        #expect(model.sections.isEmpty)
        #expect(model.loadedInput != nil)
    }

    @Test func rebuildPopulatesFromStore() async {
        let store = makeInMemoryStore()
        store.setWatched(true, for: makeMovie(id: 1, title: "A"))
        store.setDateWatched(.utc(2021, 1, 1), for: makeMovie(id: 1))
        let model = ListSectionsModel()
        await model.rebuild(for: input(source: .watched(byWatchedDate: true), count: 1), store: store)
        #expect(model.sections.flatMap(\.entries).map(\.tmdbID) == [1])
    }

    @Test func clearEmptiesSections() async {
        let store = makeInMemoryStore()
        store.recordView(makeMovie(id: 1))
        let model = ListSectionsModel()
        await model.rebuild(for: input(source: .viewed, count: 1), store: store)
        #expect(model.sections.isEmpty == false)
        model.clear()
        #expect(model.sections.isEmpty)
    }

    @Test func inputEqualityTracksEveryField() {
        let base = input(source: .viewed, count: 1, ascending: true, filter: "a", version: 1)
        #expect(base == input(source: .viewed, count: 1, ascending: true, filter: "a", version: 1))
        #expect(base != input(source: .viewed, count: 2, ascending: true, filter: "a", version: 1))
        #expect(base != input(source: .viewed, count: 1, ascending: false, filter: "a", version: 1))
        #expect(base != input(source: .viewed, count: 1, ascending: true, filter: "b", version: 1))
        #expect(base != input(source: .viewed, count: 1, ascending: true, filter: "a", version: 2))
        #expect(base != input(source: .watched(byWatchedDate: true), count: 1, ascending: true, filter: "a", version: 1))
    }
}

@Suite struct SortKeyTests {
    @Test func watchedSortKeyTitles() {
        #expect(WatchedSortKey.releaseDate.title == "Release Date")
        #expect(WatchedSortKey.dateWatched.title == "Date Watched")
    }

    @Test func listSortKeyTitlesAndRawValues() {
        #expect(ListSortKey.releaseDate.title == "Release Date")
        #expect(ListSortKey.dateAdded.title == "Date Added")
        #expect(ListSortKey(rawValue: "dateAdded") == .dateAdded)
    }
}

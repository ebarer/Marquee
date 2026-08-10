//
//  ListSectionsModelTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@MainActor
@Suite struct ListSectionsModelTests {
    private func input(request: ListRequest?, count: Int = 0, ascending: Bool = true,
                       filter: String = "", mediaFilter: MediaTypeFilter = .all,
                       version: Int = 0) -> ListSectionsModel.Input {
        .init(request: request, count: count, ascending: ascending, filter: filter,
              mediaFilter: mediaFilter, version: version)
    }

    @Test func nilSourceClearsSections() async {
        let model = ListSectionsModel()
        await model.rebuild(for: input(request:nil), store: makeInMemoryStore())
        #expect(model.sections.isEmpty)
        #expect(model.loadedInput != nil)
    }

    @Test func rebuildPopulatesFromStore() async {
        let store = makeInMemoryStore()
        store.setWatched(true, for: makeMovie(id: 1, title: "A"))
        store.setDateWatched(.utc(2021, 1, 1), for: makeMovie(id: 1))
        let model = ListSectionsModel()
        await model.rebuild(for: input(request:.watched(sort: .dateWatched), count: 1), store: store)
        #expect(model.sections.flatMap(\.entries).map(\.tmdbID) == [1])
    }

    @Test func clearEmptiesSections() async {
        let store = makeInMemoryStore()
        store.recordView(makeMovie(id: 1))
        let model = ListSectionsModel()
        await model.rebuild(for: input(request:.viewed, count: 1), store: store)
        #expect(model.sections.isEmpty == false)
        model.clear()
        #expect(model.sections.isEmpty)
    }

    @Test func inputEqualityTracksEveryField() {
        let base = input(request:.viewed, count: 1, ascending: true, filter: "a", version: 1)
        #expect(base == input(request:.viewed, count: 1, ascending: true, filter: "a", version: 1))
        #expect(base != input(request:.viewed, count: 2, ascending: true, filter: "a", version: 1))
        #expect(base != input(request:.viewed, count: 1, ascending: false, filter: "a", version: 1))
        #expect(base != input(request:.viewed, count: 1, ascending: true, filter: "b", version: 1))
        #expect(base != input(request:.viewed, count: 1, ascending: true, filter: "a", version: 2))
        #expect(base != input(request:.watched(sort: .dateWatched), count: 1, ascending: true, filter: "a", version: 1))
        #expect(base != input(request:.viewed, count: 1, ascending: true, filter: "a", mediaFilter: .movies, version: 1))
    }
}

@Suite struct SortKeyTests {
    @Test func watchedSortKeyTitles() {
        #expect(WatchedSortKey.dateWatched.title == "Date Watched")
        #expect(WatchedSortKey.releaseDate.title == "Release Date")
        #expect(WatchedSortKey.rating.title == "Rating")
    }

    @Test func listSortKeyTitlesAndRawValues() {
        #expect(ListSortKey.releaseDate.title == "Release Date")
        #expect(ListSortKey.dateAdded.title == "Date Added")
        #expect(ListSortKey(rawValue: "dateAdded") == .dateAdded)
    }
}

@Suite struct MediaTypeFilterTests {
    @Test func titlesAndSymbols() {
        #expect(MediaTypeFilter.all.title == "Movies & TV Shows")
        #expect(MediaTypeFilter.movies.title == "Movies")
        #expect(MediaTypeFilter.tv.title == "TV Shows")
        #expect(MediaTypeFilter.all.symbol == "rectangle.stack")
        #expect(MediaTypeFilter.movies.symbol == "film")
        #expect(MediaTypeFilter.tv.symbol == "tv")
    }

    @Test func matchesMediaType() {
        #expect(MediaTypeFilter.all.matches(.movie) && MediaTypeFilter.all.matches(.tv))
        #expect(MediaTypeFilter.movies.matches(.movie) && !MediaTypeFilter.movies.matches(.tv))
        #expect(!MediaTypeFilter.tv.matches(.movie) && MediaTypeFilter.tv.matches(.tv))
    }
}

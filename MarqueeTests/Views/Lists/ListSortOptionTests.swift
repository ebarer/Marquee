//
//  ListSortOptionTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct SortKeyTests {
    @Test func watchedSortKeyTitles() {
        #expect(WatchedSortKey.dateWatched.title == "Date Watched")
        #expect(WatchedSortKey.releaseDate.title == "Release Date")
        #expect(WatchedSortKey.rating.title == "Rating")
        #expect(WatchedSortKey.alphabetical.title == "Title")
    }

    @Test func listSortKeyTitlesAndRawValues() {
        #expect(ListSortKey.releaseDate.title == "Release Date")
        #expect(ListSortKey.dateAdded.title == "Date Added")
        #expect(ListSortKey.rating.title == "Rating")
        #expect(ListSortKey.alphabetical.title == "Title")
        #expect(ListSortKey(rawValue: "dateAdded") == .dateAdded)
        // A list saved before these keys existed still resolves to a sort.
        #expect(ListSortKey(rawValue: "unknown") == nil)
    }

    /// Picking a key applies this order: highest first for ratings, A→Z for titles, and for dates
    /// whichever end holds what you'd look at — a watch list's next release, a history's latest.
    @Test func defaultOrderPerSortKey() {
        #expect(WatchedSortKey.dateWatched.defaultAscending == false)
        #expect(WatchedSortKey.releaseDate.defaultAscending == false)
        #expect(WatchedSortKey.rating.defaultAscending == false)
        #expect(WatchedSortKey.alphabetical.defaultAscending == true)
        #expect(ListSortKey.releaseDate.defaultAscending == true)   // soonest release first
        #expect(ListSortKey.dateAdded.defaultAscending == false)
        #expect(ListSortKey.rating.defaultAscending == false)
        #expect(ListSortKey.alphabetical.defaultAscending == true)
    }
}

@Suite struct MediaTypeFilterTests {
    @Test func titlesAndSymbols() {
        #expect(MediaTypeFilter.all.title == "All")
        #expect(MediaTypeFilter.movies.title == "Movies")
        #expect(MediaTypeFilter.tv.title == "TV Shows")
        #expect(MediaTypeFilter.all.symbol == "rectangle.stack.badge.play")
        #expect(MediaTypeFilter.movies.symbol == "film")
        #expect(MediaTypeFilter.tv.symbol == "tv")
    }

    @Test func matchesMediaType() {
        #expect(MediaTypeFilter.all.matches(.movie) && MediaTypeFilter.all.matches(.tv))
        #expect(MediaTypeFilter.movies.matches(.movie) && !MediaTypeFilter.movies.matches(.tv))
        #expect(!MediaTypeFilter.tv.matches(.movie) && MediaTypeFilter.tv.matches(.tv))
    }
}

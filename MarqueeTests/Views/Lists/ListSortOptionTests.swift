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
    }

    @Test func listSortKeyTitlesAndRawValues() {
        #expect(ListSortKey.releaseDate.title == "Release Date")
        #expect(ListSortKey.dateAdded.title == "Date Added")
        #expect(ListSortKey(rawValue: "dateAdded") == .dateAdded)
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

//
//  ListEntryTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@Suite struct ListEntryTests {
    @Test func rebuildsMovieFromSnapshot() {
        var movie = makeMovie(id: 42, title: "Snap", poster: "/p.jpg", runtime: 88)
        movie.releaseDate = .utc(2000, 1, 1)
        let entry = ListEntry(movie: movie)
        let rebuilt = entry.movie
        #expect(rebuilt.id == 42)
        #expect(rebuilt.title == "Snap")
        #expect(rebuilt.poster == "/p.jpg")
        #expect(rebuilt.runtime == 88)
        #expect(rebuilt.releaseDate == .utc(2000, 1, 1))
        #expect(entry.mediaType == .movie)
    }

    @Test func posterURL() {
        let entry = ListEntry(movie: makeMovie(id: 1, poster: "/p.jpg"))
        #expect(entry.posterURL(.w92)?.absoluteString == "https://image.tmdb.org/t/p/w92//p.jpg")
    }
}

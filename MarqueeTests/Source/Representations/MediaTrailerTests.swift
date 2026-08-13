//
//  MediaTrailerTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct MediaTrailerTests {
    @Test func typeMapsUnknownToOther() {
        let trailer = MediaTrailer(id: "1", title: "Clip", key: "k", type: "Bloopers",
                                   site: "YouTube", official: false, publishedAt: "2020")
        #expect(trailer.type == .other)
        #expect(trailer.isTrailer == false)
    }

    @Test func isTrailerForTrailerAndTeaser() {
        func trailer(_ type: String) -> MediaTrailer {
            MediaTrailer(id: "1", title: "Clip", key: "k", type: type, site: "YouTube",
                         official: false, publishedAt: "2020")
        }
        #expect(trailer("Trailer").isTrailer)
        #expect(trailer("Teaser").isTrailer)
        #expect(trailer("Featurette").isTrailer == false)
    }

    @Test func primaryScoreRanksTrailerTeaserOfficial() {
        func score(_ type: String, _ official: Bool) -> Int {
            MediaTrailer(id: "1", title: "Clip", key: "k", type: type, site: "YouTube",
                         official: official, publishedAt: "2020").primaryScore
        }
        #expect(score("Trailer", true) == 45)
        #expect(score("Trailer", false) == 40)
        #expect(score("Teaser", true) == 35)
        #expect(score("Clip", false) == 0)
    }

    @Test func urlsBuildFromKey() {
        let trailer = MediaTrailer(id: "1", title: "Clip", key: "abc123", type: "Trailer",
                                   site: "YouTube", official: true, publishedAt: "2020")
        #expect(trailer.url?.absoluteString == "https://www.youtube.com/embed/abc123")
        #expect(trailer.watchURL?.absoluteString == "https://www.youtube.com/watch?v=abc123")
    }
}

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

    @Test func rankedKeepsPlayableTrailersBestFirst() {
        func trailer(_ id: String, _ type: String, official: Bool = true,
                     at date: String = "2020-01-01") -> MediaTrailer {
            MediaTrailer(id: id, title: id, key: "k", type: type, site: "YouTube",
                         official: official, publishedAt: date)
        }
        let ranked = MediaTrailer.ranked([
            trailer("clip", "Clip"),
            trailer("teaserOld", "Teaser", at: "2019-01-01"),
            trailer("teaserNew", "Teaser", at: "2021-01-01"),
            trailer("trailer", "Trailer"),
            MediaTrailer(id: "vimeo", title: "V", key: "k", type: "Trailer", site: "Vimeo",
                         official: true, publishedAt: "2022-01-01")
        ])
        #expect(ranked.map(\.id) == ["trailer", "teaserNew", "teaserOld"])
        #expect(MediaTrailer.ranked(nil).isEmpty)
    }

    @Test func subtitleCombinesTypeAndPublishedDate() {
        func subtitle(_ publishedAt: String) -> String {
            MediaTrailer(id: "1", title: "T", key: "k", type: "Teaser", site: "YouTube",
                         official: true, publishedAt: publishedAt).subtitle
        }
        #expect(subtitle("2026-07-21T16:00:31.000Z") == "Teaser · Jul 21, 2026")
        #expect(subtitle("2026-07-21") == "Teaser · Jul 21, 2026")
        #expect(subtitle("") == "Teaser")
    }

    @Test func urlsBuildFromKey() {
        let trailer = MediaTrailer(id: "1", title: "Clip", key: "abc123", type: "Trailer",
                                   site: "YouTube", official: true, publishedAt: "2020")
        #expect(trailer.url?.absoluteString == "https://www.youtube.com/embed/abc123")
        #expect(trailer.watchURL?.absoluteString == "https://www.youtube.com/watch?v=abc123")
    }
}

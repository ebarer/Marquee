//
//  MediaTrailerTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct MediaTrailerTests {
    @Test func typeMapsUnknownToOther() {
        let t = MediaTrailer(id: "1", title: "t", key: "k", type: "Bloopers",
                             site: "YouTube", official: false, publishedAt: "2020")
        #expect(t.type == .other)
        #expect(t.isTrailer == false)
    }

    @Test func isTrailerForTrailerAndTeaser() {
        func t(_ type: String) -> MediaTrailer {
            MediaTrailer(id: "1", title: "t", key: "k", type: type, site: "YouTube",
                         official: false, publishedAt: "2020")
        }
        #expect(t("Trailer").isTrailer)
        #expect(t("Teaser").isTrailer)
        #expect(t("Featurette").isTrailer == false)
    }

    @Test func primaryScoreRanksTrailerTeaserOfficial() {
        func score(_ type: String, _ official: Bool) -> Int {
            MediaTrailer(id: "1", title: "t", key: "k", type: type, site: "YouTube",
                         official: official, publishedAt: "2020").primaryScore
        }
        #expect(score("Trailer", true) == 45)
        #expect(score("Trailer", false) == 40)
        #expect(score("Teaser", true) == 35)
        #expect(score("Clip", false) == 0)
    }

    @Test func urlsBuildFromKey() {
        let t = MediaTrailer(id: "1", title: "t", key: "abc123", type: "Trailer",
                             site: "YouTube", official: true, publishedAt: "2020")
        #expect(t.url?.absoluteString == "https://www.youtube.com/embed/abc123")
        #expect(t.watchURL?.absoluteString == "https://www.youtube.com/watch?v=abc123")
    }
}

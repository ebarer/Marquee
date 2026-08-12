//
//  MovieTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct MovieTests {
    @Test func identityIsTMDBID() {
        var a = Movie(id: 1, title: "A")
        var b = Movie(id: 1, title: "Different Title")
        a.rating = 9; b.rating = 1
        #expect(a == b)
        #expect(Set([a, b]).count == 1)
    }

    @Test func durationFormatsHoursAndMinutes() {
        var m = Movie(id: 1, title: "A")
        #expect(m.duration == nil)
        m.runtime = 125
        #expect(m.duration == "2 hr 5 min")
        m.runtime = 45
        #expect(m.duration == "0 hr 45 min")
        m.runtime = 0                       // unknown (e.g. unreleased) — not "0 hr 0 min"
        #expect(m.duration == nil)
    }

    @Test func genresStringShortensAndJoins() {
        var m = Movie(id: 1, title: "A")
        #expect(m.genresString == "N/A")
        m.genres = ["Science Fiction"]
        #expect(m.genresString == "Sci-Fi")
        m.genres = ["Action", "Documentary"]
        #expect(m.genresString == "Action &\nDocu.")
        m.genres = ["A", "B", "C"]
        #expect(m.genresString == "N/A")
    }

    @Test func bonusStringCoversAllCombinations() {
        var m = Movie(id: 1, title: "A")
        #expect(m.bonusString == "None")
        m.bonusCredits = .init(during: false, after: true)
        #expect(m.bonusString == "After")
        m.bonusCredits = .init(during: true, after: false)
        #expect(m.bonusString == "During")
        m.bonusCredits = .init(during: true, after: true)
        #expect(m.bonusString == "During + After")
    }

    @Test func isExtraneousCreditFlagsSelfAndThanks() {
        func credit(_ role: String?) -> Movie {
            var m = Movie(id: 1, title: "A"); m.creditRole = role; return m
        }
        #expect(credit(nil).isExtraneousCredit == false)
        #expect(credit("Self").isExtraneousCredit)
        #expect(credit("self - host").isExtraneousCredit)
        #expect(credit("Self (archive footage)").isExtraneousCredit)
        #expect(credit("Special Thanks").isExtraneousCredit)
        #expect(credit("Director").isExtraneousCredit == false)
        #expect(credit("Herself").isExtraneousCredit == false)
    }

    @Test func primaryTrailerPrefersOfficialTrailerOnYouTube() {
        func t(_ id: String, _ type: String, official: Bool, at date: String) -> MediaTrailer {
            MediaTrailer(id: id, title: id, key: "k\(id)", type: type, site: "YouTube",
                         official: official, publishedAt: date)
        }
        var m = Movie(id: 1, title: "A")
        m.trailers = [
            t("clip", "Clip", official: true, at: "2020-01-01"),
            t("teaser", "Teaser", official: true, at: "2020-01-01"),
            t("trailer", "Trailer", official: false, at: "2020-01-01"),
            t("trailerOfficial", "Trailer", official: true, at: "2020-01-01"),
        ]
        #expect(m.primaryTrailer?.id == "trailerOfficial")
    }

    @Test func primaryTrailerIgnoresNonYouTubeAndClips() {
        var m = Movie(id: 1, title: "A")
        m.trailers = [
            MediaTrailer(id: "vimeo", title: "V", key: "k", type: "Trailer", site: "Vimeo",
                         official: true, publishedAt: "2021-01-01"),
            MediaTrailer(id: "clip", title: "C", key: "k", type: "Clip", site: "YouTube",
                         official: true, publishedAt: "2021-01-01"),
        ]
        #expect(m.primaryTrailer == nil)
    }

    @Test func primaryTrailerBreaksTiesByPublishDate() {
        func t(_ id: String, at date: String) -> MediaTrailer {
            MediaTrailer(id: id, title: id, key: "k", type: "Trailer", site: "YouTube",
                         official: true, publishedAt: date)
        }
        var m = Movie(id: 1, title: "A")
        m.trailers = [t("old", at: "2019-01-01"), t("new", at: "2021-06-01")]
        #expect(m.primaryTrailer?.id == "new")
    }

    @Test func posterAndBackgroundURLs() {
        var m = Movie(id: 1, title: "A")
        #expect(m.posterURL() == nil)
        m.poster = "/abc.jpg"
        #expect(m.posterURL(.w342)?.absoluteString == "https://image.tmdb.org/t/p/w342//abc.jpg")
        m.background = "/bg.jpg"
        #expect(m.backgroundURL(.w780)?.absoluteString == "https://image.tmdb.org/t/p/w780//bg.jpg")
    }
}

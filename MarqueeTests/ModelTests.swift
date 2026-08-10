//
//  ModelTests.swift
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

@Suite struct PersonTests {
    @Test func identityIsTMDBID() {
        let a = Person(id: 5, name: "A")
        let b = Person(id: 5, name: "B")
        #expect(a == b)
    }

    @Test func knownForExcludesExtraneousAndPosterlessSortedByPopularity() {
        func credit(_ id: Int, poster: String?, pop: Double, role: String? = nil) -> Movie {
            var m = Movie(id: id, title: "M\(id)")
            m.poster = poster; m.popularity = pop; m.creditRole = role
            return m
        }
        var p = Person(id: 1, name: "A")
        p.credits = [
            credit(1, poster: "/a.jpg", pop: 10),
            credit(2, poster: nil, pop: 99),                 // no poster -> excluded
            credit(3, poster: "/c.jpg", pop: 50, role: "Self"), // extraneous -> excluded
            credit(4, poster: "/d.jpg", pop: 30),
        ]
        #expect(p.knownFor.map(\.id) == [4, 1])
    }

    @Test func knownForEmptyWhenNoCredits() {
        #expect(Person(id: 1, name: "A").knownFor.isEmpty)
    }

    @Test func profileURL() {
        var p = Person(id: 1, name: "A")
        #expect(p.profileURL() == nil)
        p.profilePicture = "/pic.jpg"
        #expect(p.profileURL(.orig)?.absoluteString == "https://image.tmdb.org/t/p/original//pic.jpg")
    }
}

@Suite struct MediaTypeTests {
    @Test func rawValues() {
        #expect(MediaType.movie.rawValue == 0)
        #expect(MediaType.tv.rawValue == 1)
        #expect(MediaType(rawValue: 0) == .movie)
        #expect(MediaType(rawValue: 99) == nil)
    }
}

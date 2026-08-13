//
//  MovieTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct MovieTests {
    @Test func identityIsTMDBID() {
        var first = Movie(id: 1, title: "A")
        var second = Movie(id: 1, title: "Different Title")
        first.rating = 9; second.rating = 1
        #expect(first == second)
        #expect(Set([first, second]).count == 1)
    }

    @Test func durationFormatsHoursAndMinutes() {
        var movie = Movie(id: 1, title: "A")
        #expect(movie.duration == nil)
        movie.runtime = 125
        #expect(movie.duration == "2 hr 5 min")
        movie.runtime = 45
        #expect(movie.duration == "0 hr 45 min")
        movie.runtime = 0                       // unknown (e.g. unreleased) — not "0 hr 0 min"
        #expect(movie.duration == nil)
    }

    @Test func genresStringShortensAndJoins() {
        var movie = Movie(id: 1, title: "A")
        #expect(movie.genresString == "N/A")
        movie.genres = ["Science Fiction"]
        #expect(movie.genresString == "Sci-Fi")
        movie.genres = ["Action", "Documentary"]
        #expect(movie.genresString == "Action &\nDocu.")
        movie.genres = ["A", "B", "C"]
        #expect(movie.genresString == "N/A")
    }

    @Test func bonusStringCoversAllCombinations() {
        var movie = Movie(id: 1, title: "A")
        #expect(movie.bonusString == "None")
        movie.bonusCredits = .init(during: false, after: true)
        #expect(movie.bonusString == "After")
        movie.bonusCredits = .init(during: true, after: false)
        #expect(movie.bonusString == "During")
        movie.bonusCredits = .init(during: true, after: true)
        #expect(movie.bonusString == "During + After")
    }

    @Test func isExtraneousCreditFlagsSelfAndThanks() {
        func credit(_ role: String?) -> Movie {
            var movie = Movie(id: 1, title: "A"); movie.creditRole = role; return movie
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
        func trailer(_ id: String, _ type: String, official: Bool, at date: String) -> MediaTrailer {
            MediaTrailer(id: id, title: id, key: "k\(id)", type: type, site: "YouTube",
                         official: official, publishedAt: date)
        }
        var movie = Movie(id: 1, title: "A")
        movie.trailers = [
            trailer("clip", "Clip", official: true, at: "2020-01-01"),
            trailer("teaser", "Teaser", official: true, at: "2020-01-01"),
            trailer("trailer", "Trailer", official: false, at: "2020-01-01"),
            trailer("trailerOfficial", "Trailer", official: true, at: "2020-01-01"),
        ]
        #expect(movie.primaryTrailer?.id == "trailerOfficial")
    }

    @Test func primaryTrailerIgnoresNonYouTubeAndClips() {
        var movie = Movie(id: 1, title: "A")
        movie.trailers = [
            MediaTrailer(id: "vimeo", title: "V", key: "k", type: "Trailer", site: "Vimeo",
                         official: true, publishedAt: "2021-01-01"),
            MediaTrailer(id: "clip", title: "C", key: "k", type: "Clip", site: "YouTube",
                         official: true, publishedAt: "2021-01-01"),
        ]
        #expect(movie.primaryTrailer == nil)
    }

    @Test func primaryTrailerBreaksTiesByPublishDate() {
        func trailer(_ id: String, at date: String) -> MediaTrailer {
            MediaTrailer(id: id, title: id, key: "k", type: "Trailer", site: "YouTube",
                         official: true, publishedAt: date)
        }
        var movie = Movie(id: 1, title: "A")
        movie.trailers = [trailer("old", at: "2019-01-01"), trailer("new", at: "2021-06-01")]
        #expect(movie.primaryTrailer?.id == "new")
    }

    @Test func posterAndBackgroundURLs() {
        var movie = Movie(id: 1, title: "A")
        #expect(movie.posterURL() == nil)
        movie.poster = "/abc.jpg"
        #expect(movie.posterURL(.w342)?.absoluteString == "https://image.tmdb.org/t/p/w342//abc.jpg")
        movie.background = "/bg.jpg"
        #expect(movie.backgroundURL(.w780)?.absoluteString == "https://image.tmdb.org/t/p/w780//bg.jpg")
    }
}

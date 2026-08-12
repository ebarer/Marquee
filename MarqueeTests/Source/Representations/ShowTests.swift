//
//  ShowTests.swift
//  MarqueeTests
//
//  Show/Season/Episode computed properties + MediaSummary conformance.
//

import Foundation
import Testing
@testable import Marquee

@Suite struct ShowTests {
    private func show(first: Date?, last: Date?, status: String?) -> Show {
        var s = Show(id: 1, name: "Test")
        s.firstAirDate = first
        s.lastAirDate = last
        s.status = status
        return s
    }

    @Test func yearRangeOngoingShowsPresent() {
        #expect(show(first: .utc(2021, 9, 1), last: nil, status: "Returning Series").yearRange == "2021–Present")
    }

    @Test func yearRangeInProductionShowsPresentEvenWithLastDate() {
        #expect(show(first: .utc(2021, 9, 1), last: .utc(2023, 1, 1), status: "In Production").yearRange == "2021–Present")
    }

    @Test func yearRangeEndedMultiYear() {
        #expect(show(first: .utc(2018, 3, 4), last: .utc(2022, 5, 20), status: "Ended").yearRange == "2018–2022")
    }

    @Test func yearRangeSingleYearWhenStartEqualsEnd() {
        #expect(show(first: .utc(2020, 1, 1), last: .utc(2020, 12, 31), status: "Ended").yearRange == "2020")
    }

    @Test func yearRangeCanceledTreatedAsEnded() {
        #expect(show(first: .utc(2015, 6, 1), last: .utc(2016, 6, 1), status: "Canceled").yearRange == "2015–2016")
    }

    @Test func yearRangeNoStatusWithLastDateIsEnded() {
        #expect(show(first: .utc(2010, 1, 1), last: .utc(2012, 1, 1), status: nil).yearRange == "2010–2012")
    }

    @Test func yearRangeUnknownStatusShowsStartYearOnly() {
        // Search/list data lacks status + last-air date, so don't claim "Present".
        #expect(show(first: .utc(2019, 1, 1), last: nil, status: nil).yearRange == "2019")
    }

    @Test func yearRangeUnknownFirstAirDate() {
        #expect(show(first: nil, last: nil, status: "Returning Series").yearRange == "N/A")
    }

    @Test func seasonStartYearFromAirDate() {
        var season = Season(id: 1, seasonNumber: 2, name: "Season 2")
        season.airDate = .utc(2022, 10, 2)
        #expect(season.startYear == 2022)
        #expect(Season(id: 2, seasonNumber: 1, name: "S1").startYear == nil)
    }

    @Test func specialsSeasonDetected() {
        #expect(Season(id: 1, seasonNumber: 0, name: "Specials").isSpecials)
        #expect(!Season(id: 2, seasonNumber: 1, name: "Season 1").isSpecials)
    }

    @Test func regularSeasonsExcludeSpecialsAndUnairedThenSort() {
        var s = Show(id: 1, name: "T")
        s.seasons = [
            Season(id: 3, seasonNumber: 2, name: "S2", episodeCount: 8),
            Season(id: 1, seasonNumber: 0, name: "Specials", episodeCount: 4),
            Season(id: 2, seasonNumber: 1, name: "S1", episodeCount: 10),
            Season(id: 4, seasonNumber: 3, name: "S3"),   // announced, nothing aired yet
        ]
        #expect(s.regularSeasons.map(\.seasonNumber) == [1, 2])
    }

    @Test func episodeCodeAndDuration() {
        var e = Episode(id: 1, seasonNumber: 1, episodeNumber: 3, name: "Ep")
        e.runtime = 58
        #expect(e.code == "S1 · E3")
        #expect(e.duration == "58 min")
        e.runtime = 92
        #expect(e.duration == "1 hr 32 min")
    }

    @Test func mediaSummaryConformance() {
        var show = Show(id: 7, name: "My Show")
        show.firstAirDate = .utc(2021, 1, 1)
        show.poster = "/p.jpg"
        #expect(show.title == "My Show")
        #expect(show.mediaType == .tv)
        #expect(show.year == 2021)
        #expect(show.posterPath == "/p.jpg")

        let movie = makeMovie(id: 8, title: "My Movie", poster: "/m.jpg", release: .utc(1999, 3, 3))
        #expect(movie.mediaType == .movie)
        #expect(movie.year == 1999)
        #expect(movie.posterPath == "/m.jpg")
    }
}

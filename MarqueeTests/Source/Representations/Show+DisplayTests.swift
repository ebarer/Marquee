//
//  Show+DisplayTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct ShowDisplayTests {
    private func show(seasons: [Season]) -> Show {
        var s = Show(id: 1, name: "T")
        s.seasons = seasons
        return s
    }

    @Test func seasonCountAndLabelExcludeSpecials() {
        let s = show(seasons: [
            Season(id: 0, seasonNumber: 0, name: "Specials", episodeCount: 5),
            Season(id: 1, seasonNumber: 1, name: "S1", episodeCount: 8),
            Season(id: 2, seasonNumber: 2, name: "S2", episodeCount: 10),
        ])
        #expect(s.seasonCount == 2)
        #expect(s.seasonCountLabel == "2 Seasons")
        #expect(s.totalEpisodes == 18)   // specials excluded
    }

    @Test func singleSeasonLabelIsSingular() {
        let s = show(seasons: [Season(id: 1, seasonNumber: 1, name: "S1", episodeCount: 6)])
        #expect(s.seasonCountLabel == "1 Season")
    }

    @Test func seasonCountLabelNilWhenNoRegularSeasons() {
        #expect(show(seasons: [Season(id: 0, seasonNumber: 0, name: "Specials")]).seasonCountLabel == nil)
    }

    @Test func genresStringFormatsUpToTwo() {
        var s = Show(id: 1, name: "T")
        s.genres = ["Drama", "Comedy"]
        #expect(s.genresString == "Drama &\nComedy")
        s.genres = ["Drama"]
        #expect(s.genresString == "Drama")
        s.genres = nil
        #expect(s.genresString == "N/A")
    }

    @Test func compoundGenreFillsBothSlots() {
        var s = Show(id: 1, name: "T")
        // A single "&" genre already reads as two, so no second genre is appended, and it
        // wraps at the ampersand onto a second line.
        s.genres = ["Sci-Fi & Fantasy", "Drama"]
        #expect(s.genresString == "Sci-Fi &\nFantasy")
        #expect(Show.displayGenres(["Action & Adventure", "Sci-Fi & Fantasy"]) == ["Action & Adventure"])
        #expect(Show.displayGenres(["Drama", "Comedy"]) == ["Drama", "Comedy"])
    }

    @Test func timelineDatePrefersLastAirDate() {
        var s = Show(id: 1, name: "T")
        s.firstAirDate = .utc(2019, 1, 1)
        #expect(s.timelineDate == .utc(2019, 1, 1))   // premiere when last-air unknown
        s.lastAirDate = .utc(2026, 6, 1)
        #expect(s.timelineDate == .utc(2026, 6, 1))   // ongoing → most recent air date
    }

    @Test func primaryTrailerPrefersOfficialYouTubeTrailer() {
        var s = Show(id: 1, name: "T")
        s.trailers = [
            MediaTrailer(id: "a", title: "Clip", key: "k1", type: "Clip", site: "YouTube",
                         official: true, publishedAt: "2021-01-01"),
            MediaTrailer(id: "b", title: "Trailer", key: "k2", type: "Trailer", site: "YouTube",
                         official: true, publishedAt: "2021-02-01"),
        ]
        #expect(s.primaryTrailer?.key == "k2")
    }
}

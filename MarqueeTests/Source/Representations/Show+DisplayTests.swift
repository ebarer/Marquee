//
//  Show+DisplayTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct ShowDisplayTests {
    private func show(seasons: [Season]) -> Show {
        var result = Show(id: 1, name: "T")
        result.seasons = seasons
        return result
    }

    @Test func seasonCountAndLabelExcludeSpecials() {
        let sample = show(seasons: [
            Season(id: 0, seasonNumber: 0, name: "Specials", episodeCount: 5),
            Season(id: 1, seasonNumber: 1, name: "S1", episodeCount: 8),
            Season(id: 2, seasonNumber: 2, name: "S2", episodeCount: 10),
        ])
        #expect(sample.seasonCount == 2)
        #expect(sample.seasonCountLabel == "2 Seasons")
        #expect(sample.totalEpisodes == 18)   // specials excluded
    }

    @Test func singleSeasonLabelIsSingular() {
        let sample = show(seasons: [Season(id: 1, seasonNumber: 1, name: "S1", episodeCount: 6)])
        #expect(sample.seasonCountLabel == "1 Season")
    }

    @Test func seasonCountLabelNilWhenNoRegularSeasons() {
        #expect(show(seasons: [Season(id: 0, seasonNumber: 0, name: "Specials")]).seasonCountLabel == nil)
    }

    @Test func genresStringFormatsUpToTwo() {
        var show = Show(id: 1, name: "T")
        show.genres = ["Drama", "Comedy"]
        #expect(show.genresString == "Drama &\nComedy")
        show.genres = ["Drama"]
        #expect(show.genresString == "Drama")
        show.genres = nil
        #expect(show.genresString == "N/A")
    }

    @Test func compoundGenreFillsBothSlots() {
        var show = Show(id: 1, name: "T")
        // A single "&" genre already reads as two, so no second genre is appended, and it
        // wraps at the ampersand onto a second line.
        show.genres = ["Sci-Fi & Fantasy", "Drama"]
        #expect(show.genresString == "Sci-Fi &\nFantasy")
        #expect(Show.displayGenres(["Action & Adventure", "Sci-Fi & Fantasy"]) == ["Action & Adventure"])
        #expect(Show.displayGenres(["Drama", "Comedy"]) == ["Drama", "Comedy"])
    }

    @Test func timelineDatePrefersLastAirDate() {
        var show = Show(id: 1, name: "T")
        show.firstAirDate = .utc(2019, 1, 1)
        #expect(show.timelineDate == .utc(2019, 1, 1))   // premiere when last-air unknown
        show.lastAirDate = .utc(2026, 6, 1)
        #expect(show.timelineDate == .utc(2026, 6, 1))   // ongoing → most recent air date
    }

    @Test func primaryTrailerPrefersOfficialYouTubeTrailer() {
        var show = Show(id: 1, name: "T")
        show.trailers = [
            MediaTrailer(id: "a", title: "Clip", key: "k1", type: "Clip", site: "YouTube",
                         official: true, publishedAt: "2021-01-01"),
            MediaTrailer(id: "b", title: "Trailer", key: "k2", type: "Trailer", site: "YouTube",
                         official: true, publishedAt: "2021-02-01"),
        ]
        #expect(show.primaryTrailer?.key == "k2")
    }
}

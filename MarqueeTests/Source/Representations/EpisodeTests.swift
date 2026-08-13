//
//  EpisodeTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct EpisodeTests {
    private func episode(air: Date?) -> Episode {
        var e = Episode(id: 1, seasonNumber: 1, episodeNumber: 1, name: "Ep")
        e.airDate = air
        return e
    }

    @Test func codeAndDuration() {
        var e = Episode(id: 1, seasonNumber: 1, episodeNumber: 3, name: "Ep")
        e.runtime = 58
        #expect(e.code == "S1 · E3")
        #expect(e.duration == "58 min")
        e.runtime = 92
        #expect(e.duration == "1 hr 32 min")
    }

    @Test func durationNilWithoutRuntime() {
        #expect(Episode(id: 1, seasonNumber: 1, episodeNumber: 1, name: "Ep").duration == nil)
    }

    @Test func hasAiredForPastDates() {
        #expect(episode(air: .utc(2001, 1, 1)).hasAired)
    }

    @Test func hasNotAiredForFutureDates() {
        #expect(episode(air: Date().addingTimeInterval(60 * 60 * 24 * 30)).hasAired == false)
    }

    // An unknown air date counts as aired: TMDB omits it across parts of some back
    // catalogues, and refusing to mark those would be the worse failure.
    @Test func unknownAirDateCountsAsAired() {
        #expect(episode(air: nil).hasAired)
    }
}

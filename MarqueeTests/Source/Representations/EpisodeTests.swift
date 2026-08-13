//
//  EpisodeTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct EpisodeTests {
    private func episode(air: Date?) -> Episode {
        var result = Episode(id: 1, seasonNumber: 1, episodeNumber: 1, name: "Ep")
        result.airDate = air
        return result
    }

    @Test func codeAndDuration() {
        var sample = Episode(id: 1, seasonNumber: 1, episodeNumber: 3, name: "Ep")
        sample.runtime = 58
        #expect(sample.code == "S1 · E3")
        #expect(sample.duration == "58 min")
        sample.runtime = 92
        #expect(sample.duration == "1 hr 32 min")
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

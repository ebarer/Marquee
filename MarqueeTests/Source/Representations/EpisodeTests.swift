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

    // TMDB sends UTC midnight, which is the previous evening west of UTC.
    @Test func anEpisodeAiringTomorrowHasNotAired() {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        #expect(episode(air: MediaItem.floatingDay(from: tomorrow)).hasAired == false)
    }

    @Test func anEpisodeAiringTodayHasAired() {
        let today = Calendar.current.startOfDay(for: Date())
        #expect(episode(air: MediaItem.floatingDay(from: today)).hasAired)
    }

    // Markable the moment the local clock reaches the air day, not at UTC midnight.
    @Test func becomesAiredWhenTheLocalClockReachesMidnight() {
        let calendar = Calendar.current
        let airDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let episode = episode(air: MediaItem.floatingDay(from: airDay))
        let midnight = calendar.startOfDay(for: airDay)

        #expect(episode.hasAired(asOf: midnight.addingTimeInterval(-60)) == false)  // 23:59 the night before
        #expect(episode.hasAired(asOf: midnight.addingTimeInterval(-1)) == false)   // the last second before
        #expect(episode.hasAired(asOf: midnight))                                   // the clock strikes twelve
        #expect(episode.hasAired(asOf: midnight.addingTimeInterval(1)))
        #expect(episode.hasAired(asOf: midnight.addingTimeInterval(60 * 60 * 12)))  // and all through the day
    }

    // An unknown air date counts as aired: TMDB omits it across parts of some back
    // catalogues, and refusing to mark those would be the worse failure.
    @Test func unknownAirDateCountsAsAired() {
        #expect(episode(air: nil).hasAired)
    }
}

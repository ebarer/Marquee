//
//  EpisodeReminderPlannerTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@Suite @MainActor struct EpisodeReminderPlannerTests {
    private let store = makeInMemoryStore()

    private func coordinator() -> ListCoordinator {
        ListCoordinator(container: store.context.container)
    }

    private func addShowToWatchList(id: Int, name: String) {
        var show = Show(id: id, name: name)
        show.firstAirDate = .utc(2020, 1, 1)
        store.addToWatchList(show)
    }

    private func track(showID: Int, name: String, season: Int, next: Date?) {
        store.context.insert(TrackedSeason(showTmdbID: showID, seasonNumber: season,
                                           showName: name, posterPath: nil,
                                           episodeCount: 10, nextEpisodeDate: next))
        store.save()
    }

    private let now = Date.utc(2026, 6, 1)

    @Test func returnsUpcomingAiringsSoonestFirst() {
        addShowToWatchList(id: 1, name: "Alpha")
        addShowToWatchList(id: 2, name: "Beta")
        track(showID: 1, name: "Alpha", season: 3, next: .utc(2026, 6, 20))
        track(showID: 2, name: "Beta", season: 1, next: .utc(2026, 6, 5))

        let reminders = coordinator().episodeReminders(asOf: now)
        #expect(reminders.map(\.showName) == ["Beta", "Alpha"])
        #expect(reminders.first?.seasonNumber == 1)
    }

    @Test func skipsAiringsInThePast() {
        addShowToWatchList(id: 1, name: "Alpha")
        track(showID: 1, name: "Alpha", season: 3, next: .utc(2026, 5, 1))

        #expect(coordinator().episodeReminders(asOf: now).isEmpty)
    }

    @Test func skipsShowsWithNoKnownAirDate() {
        addShowToWatchList(id: 1, name: "Alpha")
        track(showID: 1, name: "Alpha", season: 3, next: nil)

        #expect(coordinator().episodeReminders(asOf: now).isEmpty)
    }

    // A dropped show keeps its TrackedSeason, so membership is what decides.
    @Test func ignoresShowsThatLeftTheWatchList() {
        track(showID: 9, name: "Gamma", season: 2, next: .utc(2026, 6, 10))

        #expect(coordinator().episodeReminders(asOf: now).isEmpty)
    }

    @Test func emptyWatchListYieldsNothing() {
        #expect(coordinator().episodeReminders(asOf: now).isEmpty)
    }

    // MARK: - Episode number

    @Test func theNextEpisodeIsTheFirstGapInTheSeason() {
        addShowToWatchList(id: 1, name: "Alpha")
        track(showID: 1, name: "Alpha", season: 3, next: .utc(2026, 6, 20))
        for episode in 1...4 {
            store.context.insert(WatchedEpisode(showTmdbID: 1, seasonNumber: 3,
                                                episodeNumber: episode))
        }
        store.save()

        #expect(coordinator().episodeReminders(asOf: now).first?.episodeNumber == 5)
    }

    @Test func anUnstartedSeasonPointsAtEpisodeOne() {
        addShowToWatchList(id: 1, name: "Alpha")
        track(showID: 1, name: "Alpha", season: 1, next: .utc(2026, 6, 20))

        let reminder = coordinator().episodeReminders(asOf: now).first
        #expect(reminder?.episodeNumber == 1)
        #expect(reminder?.seasonAndEpisode == "Season 1  •  Episode 1")
    }

    @Test func aGapEarlierInTheSeasonWins() {
        addShowToWatchList(id: 1, name: "Alpha")
        track(showID: 1, name: "Alpha", season: 2, next: .utc(2026, 6, 20))
        for episode in [1, 2, 4, 5] {
            store.context.insert(WatchedEpisode(showTmdbID: 1, seasonNumber: 2,
                                                episodeNumber: episode))
        }
        store.save()

        #expect(coordinator().episodeReminders(asOf: now).first?.episodeNumber == 3)
    }

    @Test func anUnknownEpisodeCountAssumesThePremiere() {
        addShowToWatchList(id: 1, name: "Alpha")
        track(showID: 1, name: "Alpha", season: 2, next: .utc(2026, 6, 20))
        if let tracked = TrackedSeason.find(showTmdbID: 1, in: store.context) {
            tracked.episodeCount = 0
            store.save()
        }

        #expect(coordinator().episodeReminders(asOf: now).first?.episodeNumber == 1)
    }
}

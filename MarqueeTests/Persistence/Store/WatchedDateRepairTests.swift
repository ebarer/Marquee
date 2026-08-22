//
//  WatchedDateRepairTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftData
@testable import Marquee

@Suite @MainActor struct WatchedDateRepairTests {
    private let store = makeInMemoryStore()

    private func coordinator() -> ListCoordinator {
        ListCoordinator(container: store.context.container)
    }

    // A bulk mark stamps each episode separately, so a run is distinct times milliseconds apart.
    private func insertRun(showID: Int, season: Int, episodes: [Int], at stamp: Date) {
        for (offset, episode) in episodes.enumerated() {
            store.context.insert(WatchedEpisode(
                showTmdbID: showID, seasonNumber: season, episodeNumber: episode,
                watchedAt: stamp.addingTimeInterval(Double(offset) * 0.002)))
        }
        store.save()
    }

    // MARK: - Detection

    @Test func aTightRunIsDetectedAsABulkMark() {
        insertRun(showID: 1, season: 1, episodes: [1, 2, 3, 4], at: .utc(2026, 8, 1))

        let found = coordinator().bulkMarkedSeasons()
        #expect(found.count == 1)
        #expect(found.first?.episodeNumbers.sorted() == [1, 2, 3, 4])
    }

    @Test func episodesWatchedDaysApartAreNotABulkMark() {
        for (offset, episode) in [1, 2, 3, 4].enumerated() {
            store.context.insert(WatchedEpisode(
                showTmdbID: 2, seasonNumber: 1, episodeNumber: episode,
                watchedAt: .utc(2026, 8, 1).addingTimeInterval(Double(offset) * 86_400)))
        }
        store.save()

        #expect(coordinator().bulkMarkedSeasons().isEmpty)
    }

    @Test func aRunShorterThanTheMinimumIsIgnored() {
        insertRun(showID: 3, season: 1, episodes: [1, 2], at: .utc(2026, 8, 1))

        #expect(coordinator().bulkMarkedSeasons().isEmpty)
    }

    @Test func twoSeparateSittingsAreSeparateRuns() {
        insertRun(showID: 4, season: 1, episodes: [1, 2, 3], at: .utc(2026, 8, 1))
        insertRun(showID: 4, season: 1, episodes: [4, 5, 6], at: .utc(2026, 8, 20))

        #expect(coordinator().bulkMarkedSeasons().count == 2)
    }

    // MARK: - Re-dating

    private func seedShow(id: Int, seasonNumber: Int, airDates: [Int: Date]) -> Show {
        var show = Show(id: id, name: "Show \(id)")
        show.status = "Ended"
        var season = Season(id: id * 100 + seasonNumber, seasonNumber: seasonNumber,
                            name: "Season \(seasonNumber)", episodeCount: airDates.count)
        season.airDate = airDates.values.min()
        season.episodes = airDates.sorted { $0.key < $1.key }.map { number, air in
            var episode = Episode(id: season.id + number, seasonNumber: seasonNumber,
                                  episodeNumber: number, name: "E\(number)")
            episode.airDate = air
            episode.runtime = 42
            return episode
        }
        show.seasons = [season]
        return show
    }

    private func watchedDate(showID: Int, season: Int, episode: Int) -> Date? {
        WatchedEpisode.find(showTmdbID: showID, seasonNumber: season,
                            episodeNumber: episode, in: store.context)?.watchedAt
    }

    // A throwaway suite per test: the one-shot flag would otherwise leak across them.
    private func freshDefaults() -> UserDefaults {
        let suite = UserDefaults(suiteName: "repair.\(UUID().uuidString)")!
        suite.removeObject(forKey: PersistenceCoordinator.repairKey)
        return suite
    }

    // The seeded shows already carry episodes, so the fetch hook only proves it isn't reached.
    private func repair(_ shows: [Show], defaults: UserDefaults? = nil) async -> Int {
        let byID = Dictionary(shows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return await store.repairBulkMarkedWatchDates(
            defaults: defaults ?? freshDefaults(),
            resolve: { byID[$0] },
            fetchSeason: { showID, number in
                byID[showID]?.seasons.first { $0.seasonNumber == number }
            })
    }

    @Test func aBackfilledRunMovesToItsAirDates() async {
        let airDates = [1: Date.utc(2011, 4, 17), 2: .utc(2011, 4, 24), 3: .utc(2011, 5, 1)]
        let show = seedShow(id: 10, seasonNumber: 1, airDates: airDates)
        insertRun(showID: 10, season: 1, episodes: [1, 2, 3], at: .utc(2026, 8, 1))

        await repair([show])

        #expect(watchedDate(showID: 10, season: 1, episode: 1) == .utc(2011, 4, 17))
        #expect(watchedDate(showID: 10, season: 1, episode: 3) == .utc(2011, 5, 1))
    }

    @Test func aRunMarkedSoonAfterAiringIsLeftAlone() async {
        let recent = Date().addingTimeInterval(-3 * 86_400)
        let show = seedShow(id: 11, seasonNumber: 1,
                            airDates: [1: recent, 2: recent, 3: recent])
        let stamp = Date()
        insertRun(showID: 11, season: 1, episodes: [1, 2, 3], at: stamp)

        #expect(await repair([show]) == 0)
        #expect(abs(watchedDate(showID: 11, season: 1, episode: 1)!.timeIntervalSince(stamp)) < 1)
    }

    @Test func theSeasonSnapshotFollowsTheRunToTheFinale() async {
        let airDates = [1: Date.utc(2011, 4, 17), 2: .utc(2011, 4, 24)]
        let show = seedShow(id: 12, seasonNumber: 1, airDates: airDates)
        let stamp = Date.utc(2026, 8, 1)
        insertRun(showID: 12, season: 1, episodes: [1, 2, 3], at: stamp)
        let snapshot = WatchedSeason(showTmdbID: 12, seasonNumber: 1, showName: "Show 12",
                                     seasonName: "Season 1", posterPath: nil,
                                     airDate: .utc(2011, 4, 24), episodeCount: 2,
                                     watchedAt: stamp)
        store.context.insert(snapshot)
        store.save()

        await repair([show])

        #expect(snapshot.watchedAt == .utc(2011, 4, 24))
    }

    // Air dates become the stamps, so a second pass finds nothing stale left to move.
    @Test func repairIsIdempotent() async {
        let airDates = [1: Date.utc(2011, 4, 17), 2: .utc(2011, 4, 24), 3: .utc(2011, 5, 1)]
        let show = seedShow(id: 13, seasonNumber: 1, airDates: airDates)
        insertRun(showID: 13, season: 1, episodes: [1, 2, 3], at: .utc(2026, 8, 1))

        #expect(await repair([show]) == 3)
        let first = watchedDate(showID: 13, season: 1, episode: 2)

        #expect(await repair([show]) == 0)
        #expect(watchedDate(showID: 13, season: 1, episode: 2) == first)
    }

    @Test func repairBackfillsMissingRuntimes() async {
        let airDates = [1: Date.utc(2011, 4, 17), 2: .utc(2011, 4, 24), 3: .utc(2011, 5, 1)]
        let show = seedShow(id: 20, seasonNumber: 1, airDates: airDates)
        insertRun(showID: 20, season: 1, episodes: [1, 2, 3], at: .utc(2026, 8, 1))

        await repair([show])

        let runtimes = WatchedEpisode.all(showTmdbID: 20, in: store.context).map(\.runtime)
        #expect(runtimes.allSatisfy { $0 == 42 })
    }

    @Test func anUnhydratedSeasonIsFetchedBeforeRedating() async {
        let airDates = [1: Date.utc(2011, 4, 17), 2: .utc(2011, 4, 24), 3: .utc(2011, 5, 1)]
        let full = seedShow(id: 21, seasonNumber: 1, airDates: airDates)
        var stub = Show(id: 21, name: "Show 21")
        var bare = Season(id: 2101, seasonNumber: 1, name: "Season 1", episodeCount: 3)
        bare.airDate = .utc(2011, 4, 17)
        stub.seasons = [bare]
        insertRun(showID: 21, season: 1, episodes: [1, 2, 3], at: .utc(2026, 8, 1))

        let moved = await store.repairBulkMarkedWatchDates(
            defaults: freshDefaults(),
            resolve: { _ in stub },
            fetchSeason: { _, number in full.seasons.first { $0.seasonNumber == number } })

        #expect(moved == 3)
        #expect(watchedDate(showID: 21, season: 1, episode: 3) == .utc(2011, 5, 1))
    }

    // The state a premiere-date fallback leaves behind: every episode already carries the season's
    // premiere, so the correction is within the season rather than back from today.
    @Test func premiereStampedEpisodesMoveToTheirOwnAirDates() async {
        let premiere = Date.utc(2011, 4, 17)
        let airDates = [1: premiere, 2: Date.utc(2011, 4, 24), 3: Date.utc(2011, 5, 1)]
        let show = seedShow(id: 30, seasonNumber: 1, airDates: airDates)
        for episode in [1, 2, 3] {
            store.context.insert(WatchedEpisode(showTmdbID: 30, seasonNumber: 1,
                                                episodeNumber: episode, watchedAt: premiere))
        }
        store.save()

        await repair([show])

        #expect(watchedDate(showID: 30, season: 1, episode: 2) == .utc(2011, 4, 24))
        #expect(watchedDate(showID: 30, season: 1, episode: 3) == .utc(2011, 5, 1))
    }

    @Test func anUnresolvedShowLeavesTheFlagClear() async {
        insertRun(showID: 14, season: 1, episodes: [1, 2, 3], at: .utc(2026, 8, 1))
        let defaults = freshDefaults()

        await repair([], defaults: defaults)

        #expect(defaults.bool(forKey: PersistenceCoordinator.repairKey) == false)
    }

    @Test func aCleanLibrarySetsTheFlagWithoutWork() async {
        let defaults = freshDefaults()

        #expect(await repair([], defaults: defaults) == 0)
        #expect(defaults.bool(forKey: PersistenceCoordinator.repairKey))
    }
}

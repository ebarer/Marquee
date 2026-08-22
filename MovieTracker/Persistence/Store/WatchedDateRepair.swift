//
//  WatchedDateRepair.swift
//  MovieTracker
//

import Foundation
import SwiftData
import OSLog

/// One season's run of episodes stamped in a single bulk mark.
struct BulkMarkedSeason: Sendable {
    let showTmdbID: Int
    let seasonNumber: Int
    let episodeNumbers: [Int]
    let stampedAt: Date
}

extension ListCoordinator {
    // A bulk mark inserts a season's episodes within milliseconds, while each manual toggle is its own
    // save seconds apart, so a tight cluster is the signature.
    static let bulkMarkWindow: TimeInterval = 60
    static let bulkMarkMinimumRun = 3

    func bulkMarkedSeasons() -> [BulkMarkedSeason] {
        let episodes = (try? modelContext.fetch(FetchDescriptor<WatchedEpisode>())) ?? []
        let bySeason = Dictionary(grouping: episodes) {
            SeasonRef(showTmdbID: $0.showTmdbID, seasonNumber: $0.seasonNumber)
        }

        var found: [BulkMarkedSeason] = []
        for (season, records) in bySeason {
            for cluster in Self.clusters(in: records.sorted { $0.watchedAt < $1.watchedAt }) {
                found.append(BulkMarkedSeason(showTmdbID: season.showTmdbID,
                                              seasonNumber: season.seasonNumber,
                                              episodeNumbers: cluster.map(\.episodeNumber),
                                              stampedAt: cluster[0].watchedAt))
            }
        }
        return found
    }

    private struct SeasonRef: Hashable {
        let showTmdbID: Int
        let seasonNumber: Int
    }

    private static func clusters(in sorted: [WatchedEpisode]) -> [[WatchedEpisode]] {
        var clusters: [[WatchedEpisode]] = []
        var current: [WatchedEpisode] = []
        for episode in sorted {
            if let first = current.first,
               episode.watchedAt.timeIntervalSince(first.watchedAt) > bulkMarkWindow {
                if current.count >= bulkMarkMinimumRun { clusters.append(current) }
                current = []
            }
            current.append(episode)
        }
        if current.count >= bulkMarkMinimumRun { clusters.append(current) }
        return clusters
    }
}

extension PersistenceCoordinator {
    // A run reads as live viewing only when the stamp is this near now and the air date this near
    // the stamp. Anything else is a back-fill.
    static let staleBulkMarkThreshold: TimeInterval = 60 * 60 * 24 * 30

    // Bump whenever the repair's rules change: the flag is what stops it re-running.
    static let repairKey = "watchedDateRepair.v3"

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Marquee",
                                    category: "WatchedDateRepair")

    // Runs until every affected season hydrates: an offline launch leaves the flag clear and retries.
    @discardableResult
    func repairBulkMarkedWatchDates(defaults: UserDefaults = .standard,
                                    resolve: ((Int) async -> Show?)? = nil,
                                    fetchSeason: ((Int, Int) async -> Season?)? = nil) async -> Int {
        guard !defaults.bool(forKey: Self.repairKey) else { return 0 }
        let resolveShow = resolve ?? { await self.resolveShow(id: $0) }
        let loadSeason = fetchSeason ?? { showID, number in
            guard let full = try? await TMDBWrapper.getSeason(showID: showID, seasonNumber: number)
            else { return nil }
            await MediaCacheStore.shared.cacheSeason(showID: showID, full)
            return full
        }

        let candidates = await readingOffMain { $0.bulkMarkedSeasons() }
        guard !candidates.isEmpty else {
            defaults.set(true, forKey: Self.repairKey)
            return 0
        }

        var moved = 0
        var unresolved = 0
        for (showID, seasons) in Dictionary(grouping: candidates, by: \.showTmdbID) {
            guard let show = await resolveShow(showID) else {
                unresolved += seasons.count
                continue
            }
            for candidate in seasons {
                var season = show.seasons.first { $0.seasonNumber == candidate.seasonNumber }
                // A premiere-dated run is exactly what needs fixing, so episodes are required.
                if season?.episodes.isEmpty ?? true {
                    season = await loadSeason(showID, candidate.seasonNumber) ?? season
                }
                guard let season, !season.episodes.isEmpty else {
                    unresolved += 1
                    continue
                }
                moved += redate(candidate, season: season)
            }
            save()
        }

        if unresolved == 0 {
            defaults.set(true, forKey: Self.repairKey)
        }
        Self.log.log("🗓️ repaired \(moved) record(s); \(unresolved) season(s) unresolved")
        return moved
    }

    private func redate(_ candidate: BulkMarkedSeason, season: Season) -> Int {
        let episodes = Dictionary(season.episodes.map { ($0.episodeNumber, $0) },
                                  uniquingKeysWith: { first, _ in first })
        var moved = 0

        for number in candidate.episodeNumbers {
            guard let record = WatchedEpisode.find(showTmdbID: candidate.showTmdbID,
                                                   seasonNumber: candidate.seasonNumber,
                                                   episodeNumber: number, in: context)
            else { continue }
            if record.runtime == nil { record.runtime = episodes[number]?.runtime }
            guard let aired = episodes[number]?.airDate ?? season.airDate,
                  record.watchedAt != aired,
                  shouldRedate(aired, stampedAt: candidate.stampedAt) else { continue }
            record.watchedAt = aired
            moved += 1
        }

        // The snapshot carries the Watched list's date, so it follows the same run to the finale.
        if let snapshot = WatchedSeason.find(showTmdbID: candidate.showTmdbID,
                                             seasonNumber: candidate.seasonNumber, in: context),
           abs(snapshot.watchedAt.timeIntervalSince(candidate.stampedAt)) <= ListCoordinator.bulkMarkWindow,
           let finale = season.episodes.compactMap(\.airDate).max() ?? season.airDate,
           snapshot.watchedAt != finale,
           shouldRedate(finale, stampedAt: snapshot.watchedAt) {
            snapshot.watchedAt = finale
            moved += 1
        }
        return moved
    }

    // A premiere-stamped back-fill fails the first test; an old one fails the second.
    private func shouldRedate(_ aired: Date, stampedAt stamp: Date,
                              now: Date = Date()) -> Bool {
        let stampIsRecent = now.timeIntervalSince(stamp) < Self.staleBulkMarkThreshold
        let airedNearStamp = abs(stamp.timeIntervalSince(aired)) < Self.staleBulkMarkThreshold
        return !(stampIsRecent && airedNearStamp)
    }
}

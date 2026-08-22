//
//  EpisodeReminderPlanner.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// One show's next airing, ready to schedule.
struct EpisodeReminder: Sendable, Equatable, Identifiable {
    let showTmdbID: Int
    let showName: String
    let seasonNumber: Int
    let episodeNumber: Int
    // Stored as UTC midnight on the day the episode airs, not a local instant.
    let airDate: Date

    var id: Int { showTmdbID }

    var seasonAndEpisode: String {
        "Season \(seasonNumber)  •  Episode \(episodeNumber)"
    }
}

extension ListCoordinator {
    func episodeReminders(asOf now: Date = Date()) -> [EpisodeReminder] {
        guard let watchList = MediaList.watchList(in: modelContext)?.uuid else { return [] }

        var entries = FetchDescriptor<ListEntry>(predicate: #Predicate { $0.list?.uuid == watchList })
        entries.propertiesToFetch = [\.tmdbID, \.mediaTypeRaw]
        let tracked = Set(((try? modelContext.fetch(entries)) ?? [])
            .filter { $0.mediaType == .tv }
            .map(\.tmdbID))
        guard !tracked.isEmpty else { return [] }

        return TrackedSeason.all(in: modelContext)
            .filter { tracked.contains($0.showTmdbID) }
            .compactMap { season in
                guard let airDate = season.nextEpisodeDate,
                      airDate.isInTheFuture(asOf: now),
                      !season.showName.isEmpty else { return nil }
                return EpisodeReminder(showTmdbID: season.showTmdbID,
                                       showName: season.showName,
                                       seasonNumber: season.seasonNumber,
                                       episodeNumber: nextEpisodeNumber(for: season),
                                       airDate: airDate)
            }
            .sorted { $0.airDate < $1.airDate }
    }

    // `nextEpisodeDate` is the first unwatched episode's air date, so its number is the season's
    // first gap. An unknown count means nothing is watched yet, which is the premiere.
    private func nextEpisodeNumber(for season: TrackedSeason) -> Int {
        guard season.episodeCount > 0 else { return 1 }
        let watched = WatchedEpisode.watchedNumbers(showTmdbID: season.showTmdbID,
                                                    seasonNumber: season.seasonNumber,
                                                    in: modelContext)
        return (1...season.episodeCount).first { !watched.contains($0) } ?? 1
    }
}

extension PersistenceCoordinator {
    func episodeReminders() async -> [EpisodeReminder] {
        await readingOffMain { $0.episodeReminders() }
    }
}

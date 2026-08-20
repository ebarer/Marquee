//
//  WatchedEpisode.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// A single watched episode, the source of truth for TV progress; season and show states derive from these.
@Model
final class WatchedEpisode {
    var showTmdbID: Int = 0
    var seasonNumber: Int = 0
    var episodeNumber: Int = 0
    var watchedAt: Date = Date()
    var addedAt: Date = Date()

    init(showTmdbID: Int, seasonNumber: Int, episodeNumber: Int, watchedAt: Date = Date()) {
        self.showTmdbID = showTmdbID
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.watchedAt = watchedAt
        self.addedAt = Date()
    }
}

extension WatchedEpisode {
    static func all(showTmdbID: Int, in context: ModelContext) -> [WatchedEpisode] {
        let descriptor = FetchDescriptor<WatchedEpisode>(
            predicate: #Predicate { $0.showTmdbID == showTmdbID })
        return (try? context.fetch(descriptor)) ?? []
    }

    static func find(showTmdbID: Int, seasonNumber: Int, episodeNumber: Int,
                     in context: ModelContext) -> WatchedEpisode? {
        var descriptor = FetchDescriptor<WatchedEpisode>(
            predicate: #Predicate {
                $0.showTmdbID == showTmdbID
                    && $0.seasonNumber == seasonNumber
                    && $0.episodeNumber == episodeNumber
            })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    static func watchedNumbers(showTmdbID: Int, seasonNumber: Int,
                               in context: ModelContext) -> Set<Int> {
        let descriptor = FetchDescriptor<WatchedEpisode>(
            predicate: #Predicate { $0.showTmdbID == showTmdbID && $0.seasonNumber == seasonNumber })
        return Set(((try? context.fetch(descriptor)) ?? []).map(\.episodeNumber))
    }

    // CloudKit has no unique constraint, so sync can create duplicates to collapse.
    @discardableResult
    static func deduplicate(in context: ModelContext) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<WatchedEpisode>())) ?? []
        let groups = Dictionary(grouping: all) {
            "\($0.showTmdbID)-\($0.seasonNumber)-\($0.episodeNumber)"
        }
        var changed = false
        for (_, items) in groups where items.count > 1 {
            for drop in items.sorted(by: { $0.addedAt < $1.addedAt }).dropFirst() {
                context.delete(drop)
            }
            changed = true
        }
        return changed
    }
}

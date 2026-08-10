//
//  TrackedSeason.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// The season a show currently *represents* in every list except Watched — its first
/// incomplete (next-to-watch) season. One row per show. Lets a membership row render as a
/// season (poster, "Season N • x of y") and, crucially, sort by the next unwatched episode's
/// air date so an in-progress show buckets near "now" instead of its premiere. Advanced as
/// seasons complete; removed once the show is fully watched or off every list. The *watched*
/// count is derived from `WatchedEpisode` (source of truth), never cached. CloudKit-friendly:
/// flat, all-defaulted, no relationships, no unique constraint.
@Model
final class TrackedSeason {
    var showTmdbID: Int = 0
    var seasonNumber: Int = 0
    var showName: String = ""
    var posterPath: String?
    /// Total episodes in the tracked season (for "x of y"); not otherwise persisted.
    var episodeCount: Int = 0
    /// Sort/bucket anchor: the first unwatched episode's air date (or the season's start
    /// when episodes aren't loaded yet).
    var nextEpisodeDate: Date?
    var updatedAt: Date = Date()
    var addedAt: Date = Date()

    init(showTmdbID: Int, seasonNumber: Int, showName: String, posterPath: String?,
         episodeCount: Int = 0, nextEpisodeDate: Date? = nil) {
        self.showTmdbID = showTmdbID
        self.seasonNumber = seasonNumber
        self.showName = showName
        self.posterPath = posterPath
        self.episodeCount = episodeCount
        self.nextEpisodeDate = nextEpisodeDate
        self.updatedAt = Date()
        self.addedAt = Date()
    }

    func posterURL(_ size: PosterSize = .w185) -> URL? {
        TMDBWrapper.imageURL(path: posterPath, size: size.rawValue)
    }
}

extension TrackedSeason {
    static func find(showTmdbID: Int, in context: ModelContext) -> TrackedSeason? {
        var descriptor = FetchDescriptor<TrackedSeason>(
            predicate: #Predicate { $0.showTmdbID == showTmdbID })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    static func all(in context: ModelContext) -> [TrackedSeason] {
        (try? context.fetch(FetchDescriptor<TrackedSeason>())) ?? []
    }

    /// CloudKit has no unique constraint, so sync can create duplicates to collapse.
    @discardableResult
    static func deduplicate(in context: ModelContext) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<TrackedSeason>())) ?? []
        let groups = Dictionary(grouping: all) { "\($0.showTmdbID)" }
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

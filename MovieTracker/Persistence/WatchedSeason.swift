//
//  WatchedSeason.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// A completed season — the display snapshot that appears as a row in the Watched list
/// (season poster, "Show — Season N", sorted to the season's finale). Written when every
/// episode of a season is watched, removed when it's no longer complete. Derived from
/// `WatchedEpisode`, but persisted so the list renders offline. CloudKit-friendly: flat,
/// all-defaulted, no relationships, no unique constraint.
@Model
final class WatchedSeason {
    var showTmdbID: Int = 0
    var seasonNumber: Int = 0
    var showName: String = ""
    var seasonName: String = ""
    var posterPath: String?
    /// Timeline anchor: the season's finale air date (or its start when episodes are unknown).
    var airDate: Date?
    /// The season's total episode count (from the show detail; not otherwise persisted, so it
    /// lives here to render "x of y" offline). The *watched* count is derived from
    /// `WatchedEpisode` — the source of truth — rather than cached, to avoid drift.
    var episodeCount: Int = 0
    var watchedAt: Date = Date()
    var addedAt: Date = Date()

    init(showTmdbID: Int, seasonNumber: Int, showName: String, seasonName: String,
         posterPath: String?, airDate: Date?, episodeCount: Int = 0, watchedAt: Date = Date()) {
        self.showTmdbID = showTmdbID
        self.seasonNumber = seasonNumber
        self.showName = showName
        self.seasonName = seasonName
        self.posterPath = posterPath
        self.airDate = airDate
        self.episodeCount = episodeCount
        self.watchedAt = watchedAt
        self.addedAt = Date()
    }

    func posterURL(_ size: Movie.PosterSize = .w185) -> URL? {
        TMDBWrapper.imageURL(path: posterPath, size: size.rawValue)
    }
}

extension WatchedSeason {
    static func find(showTmdbID: Int, seasonNumber: Int, in context: ModelContext) -> WatchedSeason? {
        var descriptor = FetchDescriptor<WatchedSeason>(
            predicate: #Predicate { $0.showTmdbID == showTmdbID && $0.seasonNumber == seasonNumber })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    static func deduplicate(in context: ModelContext) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<WatchedSeason>())) ?? []
        let groups = Dictionary(grouping: all) { "\($0.showTmdbID)-\($0.seasonNumber)" }
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

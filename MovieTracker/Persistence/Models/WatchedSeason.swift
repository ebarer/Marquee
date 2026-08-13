//
//  WatchedSeason.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// A completed season's Watched-list row. Derived from `WatchedEpisode`, but persisted as a
/// snapshot so the list renders offline; removed when the season is no longer complete.
@Model
final class WatchedSeason {
    var showTmdbID: Int = 0
    var seasonNumber: Int = 0
    var showName: String = ""
    var seasonName: String = ""
    var posterPath: String?
    /// Timeline anchor: the season's finale air date (or its start when episodes are unknown).
    var airDate: Date?
    /// Total episodes, stored so "x of y" renders offline; the *watched* count is always
    /// derived from `WatchedEpisode` rather than cached.
    var episodeCount: Int = 0
    var watchedAt: Date = Date()
    var addedAt: Date = Date()
    /// The user's star rating for this season (0–5, half-star steps); nil when unrated.
    var userRating: Double?

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

    func posterURL(_ size: PosterSize = .w185) -> URL? {
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
            let ordered = items.sorted { $0.addedAt < $1.addedAt }
            let keep = ordered[0]
            for drop in ordered.dropFirst() {
                keep.userRating = keep.userRating ?? drop.userRating
                context.delete(drop)
            }
            changed = true
        }
        return changed
    }
}

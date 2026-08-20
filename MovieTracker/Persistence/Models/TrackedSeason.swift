//
//  TrackedSeason.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// A show's first incomplete season: what it renders and sorts as in every list except Watched.
@Model
final class TrackedSeason {
    var showTmdbID: Int = 0
    var seasonNumber: Int = 0
    var showName: String = ""
    var posterPath: String?
    var episodeCount: Int = 0
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

    // CloudKit has no unique constraint, so sync can create duplicates to collapse.
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

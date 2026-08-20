//
//  MediaCachePlan.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// Buckets everything worth keeping offline into `MediaCachePriority` tiers, in prefetch order.
enum MediaCachePlan {
    // Enough to open next without dragging a long-running show's whole back catalogue offline.
    static let watchListSeasonDepth = 3
    static let discoveryDepth = 20

    @MainActor
    static func local(in context: ModelContext) -> [MediaCacheTarget] {
        var targets: [MediaCacheTarget] = []

        for entry in MediaList.watchList(in: context)?.entries ?? [] {
            targets.append(MediaCacheTarget(
                tmdbID: entry.tmdbID, mediaType: entry.mediaType, priority: .watchList,
                seasonDepth: entry.mediaType == .tv ? watchListSeasonDepth : 0))
        }

        let yearStart = MediaItem.floatingDay(from: startOfYear)
        for item in (try? context.fetch(FetchDescriptor<MediaItem>())) ?? [] {
            guard let watchedAt = item.watchedAt else { continue }
            targets.append(MediaCacheTarget(
                tmdbID: item.tmdbID, mediaType: item.mediaType,
                priority: watchedAt >= yearStart ? .recentlyWatched : .watched))
        }
        // A show can be in the Watched list through `WatchedSeason` snapshots alone, with no `MediaItem`.
        for season in (try? context.fetch(FetchDescriptor<WatchedSeason>())) ?? [] {
            targets.append(MediaCacheTarget(
                tmdbID: season.showTmdbID, mediaType: .tv,
                priority: season.watchedAt >= yearStart ? .recentlyWatched : .watched))
        }

        for list in MediaList.customLists(in: context) {
            for entry in list.entries ?? [] {
                targets.append(MediaCacheTarget(
                    tmdbID: entry.tmdbID, mediaType: entry.mediaType, priority: .customList))
            }
        }
        return targets
    }

    static func discovery(depth: Int = discoveryDepth) async -> [MediaCacheTarget] {
        var targets: [MediaCacheTarget] = []
        for collection in FeaturedCollection.allCases {
            if collection.isShow {
                guard let page = try? await collection.shows(page: 1) else { continue }
                targets += page.items.prefix(depth).map {
                    MediaCacheTarget(tmdbID: $0.id, mediaType: .tv, priority: .discovery)
                }
            } else {
                guard let page = try? await collection.movies(page: 1) else { continue }
                targets += page.items.prefix(depth).map {
                    MediaCacheTarget(tmdbID: $0.id, mediaType: .movie, priority: .discovery)
                }
            }
        }
        return targets
    }

    static func merged(_ targets: [MediaCacheTarget]) -> [MediaCacheTarget] {
        var best: [MediaCacheTarget.Identity: MediaCacheTarget] = [:]
        for target in targets {
            guard let existing = best[target.identity] else {
                best[target.identity] = target
                continue
            }
            best[target.identity] = MediaCacheTarget(
                tmdbID: target.tmdbID,
                mediaType: target.mediaType,
                priority: .best(existing.priority, target.priority),
                seasonDepth: max(existing.seasonDepth, target.seasonDepth))
        }
        return best.values.sorted {
            ($0.priority.rawValue, $0.tmdbID) < ($1.priority.rawValue, $1.tmdbID)
        }
    }

    private static var startOfYear: Date {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .distantPast
    }
}

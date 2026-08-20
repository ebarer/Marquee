//
//  MediaCachePriority.swift
//  MovieTracker
//

import Foundation

/// Retention tiers for the offline cache; eviction drops the worst tier first, ahead of recency.
enum MediaCachePriority: Int, Codable, Sendable, CaseIterable {
    case watchList = 0
    case discovery = 1
    case recentlyWatched = 2
    case customList = 3
    case watched = 4
    case browsed = 5

    static func best(_ lhs: Self, _ rhs: Self) -> Self { lhs.rawValue <= rhs.rawValue ? lhs : rhs }
}

/// One title queued for prefetch, at the tier that will govern its eviction.
struct MediaCacheTarget: Sendable {
    let tmdbID: Int
    let mediaType: MediaType
    let priority: MediaCachePriority
    var seasonDepth: Int = 0

    struct Identity: Hashable, Sendable {
        let tmdbID: Int
        let mediaType: MediaType
    }

    var identity: Identity { Identity(tmdbID: tmdbID, mediaType: mediaType) }
}

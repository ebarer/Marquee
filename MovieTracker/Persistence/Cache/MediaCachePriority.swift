//
//  MediaCachePriority.swift
//  MovieTracker
//

import Foundation

/// Retention tiers for the offline cache. Eviction drops the worst tier first, so a Watch List
/// title outlives a Discovery one no matter which was written more recently.
enum MediaCachePriority: Int, Codable, Sendable, CaseIterable {
    case watchList = 0
    case discovery = 1
    case recentlyWatched = 2
    case customList = 3
    case watched = 4
    /// Opened directly and tracked nowhere — the first to go.
    case browsed = 5

    /// The stronger of two claims on the same title.
    static func best(_ lhs: Self, _ rhs: Self) -> Self { lhs.rawValue <= rhs.rawValue ? lhs : rhs }
}

/// One title queued for prefetch, at the tier that will govern its eviction.
struct MediaCacheTarget: Sendable {
    let tmdbID: Int
    let mediaType: MediaType
    let priority: MediaCachePriority
    /// How many of a show's latest seasons to pull episodes for; 0 for movies.
    var seasonDepth: Int = 0

    struct Identity: Hashable, Sendable {
        let tmdbID: Int
        let mediaType: MediaType
    }

    var identity: Identity { Identity(tmdbID: tmdbID, mediaType: mediaType) }
}

//
//  MediaCachePrefetcher.swift
//  MovieTracker
//

import SwiftUI

/// Best-effort background pass that fills `MediaCacheStore` (and warms the image `URLCache`)
/// in `MediaCachePlan` order, so saved and Discovery titles open offline even if never viewed.
enum MediaCachePrefetcher {
    static let refreshTTL: TimeInterval = 60 * 60 * 24 * 14

    static func prefetch(_ local: [MediaCacheTarget]) async {
        let plan = MediaCachePlan.merged(local + (await MediaCachePlan.discovery()))
        await MediaCacheStore.shared.applyPriorities(plan)

        for target in plan {
            if Task.isCancelled { return }
            let reachable = target.mediaType == .tv
                ? await prefetchShow(target)
                : await prefetchMovie(target)
            // A fetch failure most likely means offline: stop, retry next launch.
            guard reachable else { return }
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    /// Returns `false` when a fetch failed, which stops the whole pass.
    private static func prefetchMovie(_ target: MediaCacheTarget) async -> Bool {
        if await MediaCacheStore.shared.isFresh(id: target.tmdbID, ttl: refreshTTL) { return true }
        guard let movie = try? await TMDBWrapper.getMovie(id: target.tmdbID) else { return false }

        let tint = await tint(for: movie.posterURL(.w342))
        await MediaCacheStore.shared.save(movie, tint: tint, priority: target.priority)

        await cacheImage(movie.posterURL(.w342))
        await cacheImage(movie.backgroundURL())
        return true
    }

    private static func prefetchShow(_ target: MediaCacheTarget) async -> Bool {
        var cached = await MediaCacheStore.shared.loadShow(id: target.tmdbID)
        let fresh = await MediaCacheStore.shared.isShowFresh(id: target.tmdbID, ttl: refreshTTL)
        if cached == nil || !fresh {
            guard let show = try? await TMDBWrapper.getShow(id: target.tmdbID) else { return false }

            let tint = await tint(for: show.posterURL(.w342))
            await MediaCacheStore.shared.save(show, tint: tint, priority: target.priority)

            await cacheImage(show.posterURL(.w342))
            await cacheImage(show.backgroundURL())
            // Re-read: the save merges episodes cached on an earlier launch back in, and the
            // season pass below needs to see them.
            cached = await MediaCacheStore.shared.loadShow(id: target.tmdbID)
        }
        guard target.seasonDepth > 0, let show = cached?.show else { return true }

        for season in show.regularSeasons.suffix(target.seasonDepth) {
            if Task.isCancelled { return true }
            // Already whole in the cache; a newly aired episode raises `episodeCount` past it.
            if !season.episodes.isEmpty, season.episodes.count >= season.episodeCount { continue }
            guard let full = try? await TMDBWrapper.getSeason(showID: show.id,
                                                             seasonNumber: season.seasonNumber)
            else { return false }
            await MediaCacheStore.shared.cacheSeason(showID: show.id, full)
            await cacheImage(season.posterURL(.w342))
            try? await Task.sleep(for: .milliseconds(300))
        }
        return true
    }

    private static func tint(for url: URL?) async -> Color? {
        guard let url, let data = try? await TMDBWrapper.imageData(from: url) else { return nil }
        return Color.averageColor(from: data)
    }

    private static func cacheImage(_ url: URL?) async {
        guard let url else { return }
        _ = try? await URLSession.shared.data(from: url)
    }
}

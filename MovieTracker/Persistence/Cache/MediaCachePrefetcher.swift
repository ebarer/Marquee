//
//  MediaCachePrefetcher.swift
//  MovieTracker
//

import SwiftUI

/// Best-effort background pass filling `MediaCacheStore` and warming the image `URLCache`.
enum MediaCachePrefetcher {
    static let refreshTTL: TimeInterval = 60 * 60 * 24 * 14

    static func prefetch(_ local: [MediaCacheTarget]) async {
        let plan = MediaCachePlan.merged(local + (await MediaCachePlan.discovery()))
        await MediaCacheStore.shared.applyPriorities(plan)

        for target in plan {
            if Task.isCancelled { return }
            let outcome = target.mediaType == .tv
                ? await prefetchShow(target)
                : await prefetchMovie(target)
            // Only a transport failure means offline. A title TMDB refuses is skipped, or one bad
            // entry would starve every target behind it on every launch.
            guard outcome != .offline else { return }
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    private enum Outcome {
        case done, skipped, offline
    }

    private static func outcome(for error: Error) -> Outcome {
        error.isPermanentHTTPFailure ? .skipped : .offline
    }

    private static func prefetchMovie(_ target: MediaCacheTarget) async -> Outcome {
        if await MediaCacheStore.shared.isFresh(id: target.tmdbID, ttl: refreshTTL) { return .done }
        let movie: Movie
        do {
            movie = try await TMDBWrapper.getMovie(id: target.tmdbID)
        } catch {
            return outcome(for: error)
        }

        let tint = await tint(for: movie.posterURL(.w342))
        await MediaCacheStore.shared.save(movie, tint: tint, priority: target.priority)

        await cacheImage(movie.posterURL(.w342))
        await cacheImage(movie.backgroundURL())
        return .done
    }

    private static func prefetchShow(_ target: MediaCacheTarget) async -> Outcome {
        var cached = await MediaCacheStore.shared.loadShow(id: target.tmdbID)
        let fresh = await MediaCacheStore.shared.isShowFresh(id: target.tmdbID, ttl: refreshTTL)
        if cached == nil || !fresh {
            let show: Show
            do {
                show = try await TMDBWrapper.getShow(id: target.tmdbID)
            } catch {
                return outcome(for: error)
            }

            let tint = await tint(for: show.posterURL(.w342))
            await MediaCacheStore.shared.save(show, tint: tint, priority: target.priority)

            await cacheImage(show.posterURL(.w342))
            await cacheImage(show.backgroundURL())
            // Re-read: the save merges episodes cached on an earlier launch back in, and the season pass needs them.
            cached = await MediaCacheStore.shared.loadShow(id: target.tmdbID)
        }
        guard target.seasonDepth > 0, let show = cached?.show else { return .done }

        for season in show.regularSeasons.suffix(target.seasonDepth) {
            if Task.isCancelled { return .done }
            // Already whole in the cache; a newly aired episode raises `episodeCount` past it.
            let whole = !season.episodes.isEmpty && season.episodes.count >= season.episodeCount
            if whole, await MediaCacheStore.shared.isSeasonFresh(
                showID: show.id, seasonNumber: season.seasonNumber,
                ttl: MediaCacheStore.seasonRefreshTTL) { continue }
            do {
                let full = try await TMDBWrapper.getSeason(showID: show.id,
                                                          seasonNumber: season.seasonNumber)
                await MediaCacheStore.shared.cacheSeason(showID: show.id, full)
            } catch {
                // A season TMDB won't serve shouldn't cost the show's remaining seasons.
                guard error.isPermanentHTTPFailure else { return .offline }
                continue
            }
            await cacheImage(season.posterURL(.w342))
            try? await Task.sleep(for: .milliseconds(300))
        }
        return .done
    }

    private static func tint(for url: URL?) async -> Color? {
        guard let url, let data = try? await TMDBWrapper.imageData(from: url) else { return nil }
        return Color.dominantColor(from: data)
    }

    private static func cacheImage(_ url: URL?) async {
        guard let url else { return }
        _ = try? await URLSession.shared.data(from: url)
    }
}

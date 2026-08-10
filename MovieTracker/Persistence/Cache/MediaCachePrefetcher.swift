//
//  MediaCachePrefetcher.swift
//  MovieTracker
//

import SwiftUI

/// Best-effort background pass that fills `MediaCacheStore` (and warms the image
/// `URLCache`) for saved titles, so they open offline even if never viewed.
enum MediaCachePrefetcher {
    static let refreshTTL: TimeInterval = 60 * 60 * 24 * 14

    static func prefetch(ids: [Int]) async {
        for id in ids {
            if Task.isCancelled { return }
            if await MediaCacheStore.shared.isFresh(id: id, ttl: refreshTTL) { continue }

            // A fetch failure most likely means offline: stop, retry next launch.
            guard let movie = try? await TMDBWrapper.getMovie(id: id) else { return }

            var tint: Color?
            if let url = movie.posterURL(.w342),
               let data = try? await TMDBWrapper.imageData(from: url) {
                tint = Color.averageColor(from: data)
            }
            await MediaCacheStore.shared.save(movie, tint: tint)

            await cacheImage(movie.posterURL(.w342))
            await cacheImage(movie.backgroundURL())

            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    private static func cacheImage(_ url: URL?) async {
        guard let url else { return }
        _ = try? await URLSession.shared.data(from: url)
    }
}

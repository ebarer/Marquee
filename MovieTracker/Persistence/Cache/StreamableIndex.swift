//
//  StreamableIndex.swift
//  MovieTracker
//

import Foundation

struct StreamableFilter: Equatable, Sendable {
    var region: String
    var scope: StreamingScope
    var selected: SelectedProviders

    var signature: String { "\(region)|\(scope.rawValue)|\(selected.rawValue)" }
}

/// Memoized streamability for cached titles, so a list filter never decodes a payload twice.
actor StreamableIndex {
    static let shared = StreamableIndex()

    private var signature = ""
    private var known: [MediaCacheTarget.Identity: Bool] = [:]

    func streamable(_ targets: [MediaCacheTarget.Identity],
                    using filter: StreamableFilter) async -> Set<MediaCacheTarget.Identity> {
        if filter.signature != signature {
            signature = filter.signature
            known = [:]
        }
        var result: Set<MediaCacheTarget.Identity> = []
        for target in targets {
            if let answer = known[target] {
                if answer { result.insert(target) }
                continue
            }
            // A title the cache has never held stays unanswered, so a later prefetch can still place it.
            guard let answer = await resolve(target, using: filter) else { continue }
            known[target] = answer
            if answer { result.insert(target) }
        }
        return result
    }

    private func resolve(_ target: MediaCacheTarget.Identity,
                         using filter: StreamableFilter) async -> Bool? {
        let availability: WatchAvailability?
        switch target.mediaType {
        case .tv:
            guard let show = await MediaCacheStore.shared.loadShow(id: target.tmdbID)?.show
            else { return nil }
            availability = show.watch(for: filter.region)
        case .movie:
            guard let movie = await MediaCacheStore.shared.load(id: target.tmdbID)?.movie
            else { return nil }
            availability = movie.watch(for: filter.region)
        }
        // Streamable means the scope has something to play, not what the verdict happens to word it as.
        return !StreamingAvailability.resolve(availability, scope: filter.scope,
                                              selected: filter.selected).groups.isEmpty
    }
}

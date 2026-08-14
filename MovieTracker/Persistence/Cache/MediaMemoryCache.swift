//
//  MediaMemoryCache.swift
//  MovieTracker
//

import SwiftUI

/// Payloads already fetched this session, readable synchronously. `MediaCacheStore` sits behind
/// an actor and a disk read, so a detail page can't consult it before its first frame.
@MainActor
enum MediaMemoryCache {
    struct Entry {
        let movie: Movie
        let tint: Color?
    }

    private static var entries: [Int: Entry] = [:]
    private static var order: [Int] = []
    private static let limit = 60

    static func movie(id: Int?) -> Entry? {
        guard let id else { return nil }
        return entries[id]
    }

    static func store(_ movie: Movie, tint: Color?) {
        if entries[movie.id] == nil { order.append(movie.id) }
        entries[movie.id] = Entry(movie: movie, tint: tint)
        while order.count > limit, let oldest = order.first {
            order.removeFirst()
            entries[oldest] = nil
        }
    }

    static func removeAll() {
        entries.removeAll()
        order.removeAll()
    }
}

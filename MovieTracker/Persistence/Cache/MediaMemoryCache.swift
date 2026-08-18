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

    struct ShowEntry {
        let show: Show
        let tint: Color?
    }

    // Movies and shows keep separate buckets: a TMDB id is only unique within its media type.
    private static var movies = Bucket<Entry>()
    private static var shows = Bucket<ShowEntry>()

    static func movie(id: Int?) -> Entry? {
        guard let id else { return nil }
        return movies[id]
    }

    static func show(id: Int?) -> ShowEntry? {
        guard let id else { return nil }
        return shows[id]
    }

    static func store(_ movie: Movie, tint: Color?) {
        movies.insert(Entry(movie: movie, tint: tint), id: movie.id)
    }

    static func store(_ show: Show, tint: Color?) {
        shows.insert(ShowEntry(show: show, tint: tint), id: show.id)
    }

    static func removeAll() {
        movies = Bucket()
        shows = Bucket()
    }

    private struct Bucket<Value> {
        private static var limit: Int { 60 }

        private var entries: [Int: Value] = [:]
        private var order: [Int] = []

        subscript(id: Int) -> Value? { entries[id] }

        mutating func insert(_ value: Value, id: Int) {
            if entries[id] == nil { order.append(id) }
            entries[id] = value
            while order.count > Self.limit, let oldest = order.first {
                order.removeFirst()
                entries[oldest] = nil
            }
        }
    }
}

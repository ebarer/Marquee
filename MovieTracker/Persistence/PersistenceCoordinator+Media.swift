//
//  PersistenceCoordinator+Media.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

extension PersistenceCoordinator {

    // MARK: - Reads

    func isWatched(_ movie: Movie) -> Bool { MediaItem.isWatched(movie, in: context) }
    func rating(for movie: Movie) -> Double? { MediaItem.rating(for: movie, in: context) }
    func dateWatched(for movie: Movie) -> Date? { MediaItem.dateWatched(for: movie, in: context) }

    var watchedCount: Int {
        (try? context.fetchCount(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.watchedAt != nil }))) ?? 0
    }
    var viewedCount: Int {
        (try? context.fetchCount(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.lastViewedAt != nil }))) ?? 0
    }

    func savedMovieIDs() -> [Int] {
        let movieType = MediaType.movie.rawValue
        let entries = (try? context.fetch(FetchDescriptor<ListEntry>())) ?? []
        let items = (try? context.fetch(FetchDescriptor<MediaItem>())) ?? []
        let ids = Set(entries.filter { $0.mediaTypeRaw == movieType }.map(\.tmdbID))
            .union(items.filter { $0.mediaTypeRaw == movieType }.map(\.tmdbID))
        return Array(ids)
    }

    // MARK: - Fact writes

    func setWatched(_ watched: Bool, for movie: Movie) {
        MediaItem.setWatched(watched, for: movie, in: context); save()
    }
    func setRating(_ stars: Double?, for movie: Movie) {
        MediaItem.setRating(stars, for: movie, in: context); save()
    }
    func setDateWatched(_ date: Date?, for movie: Movie) {
        MediaItem.setDateWatched(date, for: movie, in: context); save()
    }
    func recordView(_ movie: Movie) {
        MediaItem.recordView(movie, in: context); save()
    }

    // MARK: - Clearing derived state

    func unwatch(_ item: MediaItem) { item.watchedAt = nil; item.pruneIfEmpty(); save() }
    func removeFromViewed(_ item: MediaItem) { item.lastViewedAt = nil; item.pruneIfEmpty(); save() }

    func unwatch(_ id: PersistentIdentifier) {
        if let item = context.model(for: id) as? MediaItem { unwatch(item) }
    }
    func removeFromViewed(_ id: PersistentIdentifier) {
        if let item = context.model(for: id) as? MediaItem { removeFromViewed(item) }
    }

    func clearViewed() {
        let items = (try? context.fetch(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.lastViewedAt != nil }))) ?? []
        for item in items {
            item.lastViewedAt = nil
            item.pruneIfEmpty()
        }
        save()
    }
}

//
//  PersistenceCoordinator+Media.swift
//  MovieTracker
//
//  Per-title facts: the private Watched / rating / Viewed state read and written
//  through `MediaItem`, plus the derived Watched / Viewed counts. These never touch
//  list membership directly — the model rules bridge the two.
//

import SwiftUI
import SwiftData

extension PersistenceCoordinator {

    // MARK: - Reads (so views never touch the context)

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

    /// Clears a derived flag (Watched / Viewed) and prunes the item if it's now empty.
    func unwatch(_ item: MediaItem) { item.watchedAt = nil; item.pruneIfEmpty(); save() }
    func removeFromViewed(_ item: MediaItem) { item.lastViewedAt = nil; item.pruneIfEmpty(); save() }

    /// The same, resolving a row-snapshot id back to its live model. No-op if gone.
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

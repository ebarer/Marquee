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

    func isWatched(_ show: Show) -> Bool { MediaItem.isWatched(key: show.mediaKey, in: context) }
    func rating(for show: Show) -> Double? { MediaItem.rating(for: show.mediaKey, in: context) }
    func dateWatched(for show: Show) -> Date? { MediaItem.dateWatched(for: show.mediaKey, in: context) }

    func isWatched(key: MediaKey) -> Bool { MediaItem.isWatched(key: key, in: context) }
    func setWatched(_ watched: Bool, forKey key: MediaKey) {
        applyWatched(watched, forKey: key); save()
    }

    /// Un-marking parks the watched date and re-marking restores it, so an accidental toggle
    /// costs nothing. With none remembered, marking watched dates to today as usual.
    private func applyWatched(_ watched: Bool, forKey key: MediaKey) {
        guard watched else {
            watchedMemory.remember(MediaItem.dateWatched(for: key, in: context), for: key)
            MediaItem.setWatched(false, for: key, in: context)
            return
        }
        MediaItem.setWatched(true, for: key, in: context)
        if let remembered = watchedMemory.takeDate(for: key) {
            MediaItem.setDateWatched(remembered, for: key, in: context)
        }
    }

    /// Watched movies plus watched TV seasons (which track separately). Memoised against
    /// `revision`: both counts sit in view bodies that re-run constantly.
    var watchedCount: Int {
        cachedCount(.watched) {
            let movieType = MediaType.movie.rawValue
            let movies = (try? context.fetchCount(FetchDescriptor<MediaItem>(
                predicate: #Predicate { $0.watchedAt != nil && $0.mediaTypeRaw == movieType }))) ?? 0
            let seasons = (try? context.fetchCount(FetchDescriptor<WatchedSeason>())) ?? 0
            return movies + seasons
        }
    }
    var viewedCount: Int {
        cachedCount(.viewed) {
            (try? context.fetchCount(FetchDescriptor<MediaItem>(
                predicate: #Predicate { $0.lastViewedAt != nil }))) ?? 0
        }
    }

    // MARK: - Fact writes

    func setWatched(_ watched: Bool, for movie: Movie) {
        applyWatched(watched, forKey: movie.mediaKey); save()
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

    func setWatched(_ watched: Bool, for show: Show) {
        applyWatched(watched, forKey: show.mediaKey); save()
    }
    func setRating(_ stars: Double?, for show: Show) {
        MediaItem.setRating(stars, for: show.mediaKey, in: context); save()
    }
    func setDateWatched(_ date: Date?, for show: Show) {
        MediaItem.setDateWatched(date, for: show.mediaKey, in: context); save()
    }
    func recordView(_ show: Show) {
        MediaItem.recordView(key: show.mediaKey, in: context); save()
    }

    /// Refresh a tracked show's snapshot once its detail loads — search-added shows start with
    /// only a premiere date, so this corrects their timeline placement.
    func refreshSnapshot(for show: Show) {
        let key = show.mediaKey
        let tmdbID = key.tmdbID
        let raw = key.mediaType.rawValue
        var changed = false

        if let item = MediaItem.find(key: key, in: context) {
            item.refreshSnapshot(from: key)
            changed = true
        }
        let entries = (try? context.fetch(FetchDescriptor<ListEntry>(
            predicate: #Predicate { $0.tmdbID == tmdbID && $0.mediaTypeRaw == raw }))) ?? []
        for entry in entries {
            entry.refreshSnapshot(from: key)
            changed = true
        }
        if changed { save() }
    }

    // Key-based writes, so shared controls (StarRating, WatchedDateButton) work for either type.
    func setRating(_ stars: Double?, forKey key: MediaKey) {
        MediaItem.setRating(stars, for: key, in: context); save()
    }
    func setDateWatched(_ date: Date?, forKey key: MediaKey) {
        MediaItem.setDateWatched(date, for: key, in: context); save()
    }

    // MARK: - Clearing derived state

    func unwatch(_ item: MediaItem) {
        watchedMemory.remember(item.watchedAt, tmdbID: item.tmdbID, mediaType: item.mediaType)
        item.watchedAt = nil
        item.pruneIfEmpty()
        save()
    }
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

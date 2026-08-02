//
//  MediaItem.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// A tracked title's **private** per-user state — rating, watched date, and last
/// viewed time — plus a display snapshot. One row per (`tmdbID`, `mediaType`).
/// Never shared; list membership lives separately in `ListEntry`. Watched and
/// Viewed are derived from this (`watchedAt`/`lastViewedAt`), not from lists.
@Model
final class MediaItem {
    var tmdbID: Int = 0
    var mediaTypeRaw: Int = MediaType.movie.rawValue
    var title: String = ""
    var posterPath: String?
    var releaseDate: Date?
    var runtime: Int?
    /// Personal rating in stars (0.5–5.0, half steps).
    var userRating: Double?
    /// Non-nil ⇒ Watched. Stored as a canonical UTC-midnight day (see `floatingDay`).
    var watchedAt: Date?
    /// Non-nil ⇒ in the Viewed history; the browse timestamp.
    var lastViewedAt: Date?
    var addedAt: Date = Date()

    init(tmdbID: Int, mediaType: MediaType = .movie, title: String) {
        self.tmdbID = tmdbID
        self.mediaTypeRaw = mediaType.rawValue
        self.title = title
    }

    convenience init(movie: Movie) {
        self.init(tmdbID: movie.id, title: movie.title)
        refreshSnapshot(from: movie)
    }

    var mediaType: MediaType { MediaType(rawValue: mediaTypeRaw) ?? .movie }
    var isWatched: Bool { watchedAt != nil }

    func posterURL(_ size: Movie.PosterSize = .w185) -> URL? {
        TMDBWrapper.imageURL(path: posterPath, size: size.rawValue)
    }

    /// Refreshes the display snapshot from a freshly-fetched DTO.
    func refreshSnapshot(from movie: Movie) {
        title = movie.title
        posterPath = movie.poster
        releaseDate = movie.releaseDate
        runtime = movie.runtime
    }

    /// Deletes this item once it carries no personal state — a `MediaItem` only
    /// exists to hold facts; list membership is `ListEntry`.
    func pruneIfEmpty() {
        guard userRating == nil, watchedAt == nil, lastViewedAt == nil else { return }
        modelContext?.delete(self)
    }
}

// MARK: - Lookup / upsert

extension MediaItem {
    static func find(tmdbID: Int, mediaType: MediaType = .movie, in context: ModelContext) -> MediaItem? {
        let raw = mediaType.rawValue
        var descriptor = FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.tmdbID == tmdbID && $0.mediaTypeRaw == raw }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    static func find(_ movie: Movie, in context: ModelContext) -> MediaItem? {
        find(tmdbID: movie.id, in: context)
    }

    /// The existing item for a movie, or a freshly inserted one, snapshot refreshed.
    @discardableResult
    static func upsert(_ movie: Movie, in context: ModelContext) -> MediaItem {
        if let existing = find(movie, in: context) {
            existing.refreshSnapshot(from: movie)
            return existing
        }
        let item = MediaItem(movie: movie)
        context.insert(item)
        return item
    }
}

// MARK: - Facts (movie-keyed conveniences)

extension MediaItem {
    static func rating(for movie: Movie, in context: ModelContext) -> Double? {
        find(movie, in: context)?.userRating
    }

    /// Sets or clears (`nil`/≤0) the personal rating, snapped to the nearest half
    /// star. Removes the item if it ends up holding no state.
    static func setRating(_ stars: Double?, for movie: Movie, in context: ModelContext) {
        let snapped = stars.flatMap { $0 > 0 ? ($0 * 2).rounded() / 2 : nil }
        if snapped == nil, find(movie, in: context) == nil { return }
        let item = upsert(movie, in: context)
        item.userRating = snapped
        item.pruneIfEmpty()
    }

    static func isWatched(_ movie: Movie, in context: ModelContext) -> Bool {
        find(movie, in: context)?.isWatched ?? false
    }

    static func dateWatched(for movie: Movie, in context: ModelContext) -> Date? {
        find(movie, in: context)?.watchedAt
    }

    static func setDateWatched(_ date: Date?, for movie: Movie, in context: ModelContext) {
        find(movie, in: context)?.watchedAt = date
    }

    /// Marks a movie watched (or unmarks it). Marking removes it from the Watch
    /// List (the two are mutually exclusive); unmarking prunes an empty item.
    static func setWatched(_ watched: Bool, for movie: Movie, in context: ModelContext) {
        if watched {
            let item = upsert(movie, in: context)
            item.watchedAt = floatingDay(from: Date())
            MediaList.watchList(in: context)?.remove(movie)
        } else if let item = find(movie, in: context) {
            item.watchedAt = nil
            item.pruneIfEmpty()
        }
    }

    /// Records that a title's detail page was browsed, keeping the Viewed history
    /// to the most-recent `limit` items (older ones fall out of the history).
    static func recordView(_ movie: Movie, in context: ModelContext, keeping limit: Int = 20) {
        upsert(movie, in: context).lastViewedAt = Date()

        let descriptor = FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.lastViewedAt != nil },
            sortBy: [SortDescriptor(\.lastViewedAt, order: .reverse)]
        )
        let viewed = (try? context.fetch(descriptor)) ?? []
        for stale in viewed.dropFirst(limit) {
            stale.lastViewedAt = nil
            stale.pruneIfEmpty()
        }
    }
}

// MARK: - Watched-date timezone

extension MediaItem {
    /// A watched date stored canonically as midnight UTC for a calendar day, so it
    /// reads as the same day on every device. Pass a local-time date; its local
    /// year/month/day is preserved.
    static func floatingDay(from localDate: Date) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: localDate)
        return utc.date(from: comps) ?? localDate
    }

    /// Converts a canonical UTC-midnight watched date back to local midnight.
    static func localDay(from storedDate: Date) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = utc.dateComponents([.year, .month, .day], from: storedDate)
        return Calendar.current.date(from: comps) ?? storedDate
    }
}

// MARK: - De-duplication

extension MediaItem {
    /// Collapses items sharing a (`tmdbID`, `mediaType`) — a CloudKit sync can
    /// create duplicates since there's no unique constraint. Keeps the earliest
    /// `addedAt` and OR-s the facts together.
    @discardableResult
    static func deduplicate(in context: ModelContext) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<MediaItem>())) ?? []
        let groups = Dictionary(grouping: all) { "\($0.tmdbID)-\($0.mediaTypeRaw)" }
        var changed = false
        for (_, items) in groups where items.count > 1 {
            let ordered = items.sorted { $0.addedAt < $1.addedAt }
            let keep = ordered[0]
            for drop in ordered.dropFirst() {
                keep.userRating = keep.userRating ?? drop.userRating
                keep.watchedAt = keep.watchedAt ?? drop.watchedAt
                keep.lastViewedAt = keep.lastViewedAt ?? drop.lastViewedAt
                context.delete(drop)
            }
            changed = true
        }
        return changed
    }
}

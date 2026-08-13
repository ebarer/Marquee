//
//  MediaItem.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// A tracked title's private per-user state; list membership lives in `ListEntry`.
@Model
final class MediaItem {
    var tmdbID: Int = 0
    var mediaTypeRaw: Int = MediaType.movie.rawValue
    var title: String = ""
    var posterPath: String?
    var releaseDate: Date?
    /// Timeline anchor for list sorting; nil means "use releaseDate" (all movies, and
    /// shows whose most-recent air date isn't known yet). Additive/optional for CloudKit.
    var sortDate: Date?
    var runtime: Int?
    var userRating: Double?
    /// Stored as a canonical UTC-midnight day (see `floatingDay`).
    var watchedAt: Date?
    var lastViewedAt: Date?
    var addedAt: Date = Date()
    /// Cached "every aired season is watched" for `.tv`, so show detail is right on entry.
    /// Kept in sync by `reconcileMembership`/`unwatchSeason`; nil for movies.
    var showWatched: Bool?
    /// The user removed this show from the auto-managed Watch List; persisted so watched
    /// progress can't bounce it back on. Cleared by `restoreToWatchList`.
    var watchListOptOut: Bool?

    init(tmdbID: Int, mediaType: MediaType = .movie, title: String) {
        self.tmdbID = tmdbID
        self.mediaTypeRaw = mediaType.rawValue
        self.title = title
    }

    convenience init(movie: Movie) {
        self.init(key: movie.mediaKey)
    }

    convenience init(key: MediaKey) {
        self.init(tmdbID: key.tmdbID, mediaType: key.mediaType, title: key.title)
        refreshSnapshot(from: key)
    }

    var mediaType: MediaType { MediaType(rawValue: mediaTypeRaw) ?? .movie }
    var isWatched: Bool { watchedAt != nil }

    func posterURL(_ size: PosterSize = .w185) -> URL? {
        TMDBWrapper.imageURL(path: posterPath, size: size.rawValue)
    }

    func refreshSnapshot(from movie: Movie) {
        refreshSnapshot(from: movie.mediaKey)
    }

    func refreshSnapshot(from key: MediaKey) {
        title = key.title
        posterPath = key.posterPath
        releaseDate = key.releaseDate
        runtime = key.runtime
        // Don't clobber a known timeline date with nil (search-sourced keys lack it).
        if let sortDate = key.sortDate { self.sortDate = sortDate }
    }

    func pruneIfEmpty() {
        guard userRating == nil, watchedAt == nil, lastViewedAt == nil,
              showWatched != true, watchListOptOut != true else { return }
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

    static func find(key: MediaKey, in context: ModelContext) -> MediaItem? {
        find(tmdbID: key.tmdbID, mediaType: key.mediaType, in: context)
    }

    static func find(_ movie: Movie, in context: ModelContext) -> MediaItem? {
        find(key: movie.mediaKey, in: context)
    }

    @discardableResult
    static func upsert(key: MediaKey, in context: ModelContext) -> MediaItem {
        if let existing = find(key: key, in: context) {
            existing.refreshSnapshot(from: key)
            return existing
        }
        let item = MediaItem(key: key)
        context.insert(item)
        return item
    }

    @discardableResult
    static func upsert(_ movie: Movie, in context: ModelContext) -> MediaItem {
        upsert(key: movie.mediaKey, in: context)
    }
}

// MARK: - Facts (key-keyed core, with Movie conveniences)

extension MediaItem {
    static func rating(for key: MediaKey, in context: ModelContext) -> Double? {
        find(key: key, in: context)?.userRating
    }
    static func rating(for movie: Movie, in context: ModelContext) -> Double? {
        rating(for: movie.mediaKey, in: context)
    }

    static func setRating(_ stars: Double?, for key: MediaKey, in context: ModelContext) {
        let snapped = stars.flatMap { $0 > 0 ? ($0 * 2).rounded() / 2 : nil }
        if snapped == nil, find(key: key, in: context) == nil { return }
        let item = upsert(key: key, in: context)
        item.userRating = snapped
        item.pruneIfEmpty()
    }
    static func setRating(_ stars: Double?, for movie: Movie, in context: ModelContext) {
        setRating(stars, for: movie.mediaKey, in: context)
    }

    static func isWatched(key: MediaKey, in context: ModelContext) -> Bool {
        find(key: key, in: context)?.isWatched ?? false
    }
    static func isWatched(_ movie: Movie, in context: ModelContext) -> Bool {
        isWatched(key: movie.mediaKey, in: context)
    }

    static func dateWatched(for key: MediaKey, in context: ModelContext) -> Date? {
        find(key: key, in: context)?.watchedAt
    }
    static func dateWatched(for movie: Movie, in context: ModelContext) -> Date? {
        dateWatched(for: movie.mediaKey, in: context)
    }

    static func setDateWatched(_ date: Date?, for key: MediaKey, in context: ModelContext) {
        find(key: key, in: context)?.watchedAt = date
    }
    static func setDateWatched(_ date: Date?, for movie: Movie, in context: ModelContext) {
        setDateWatched(date, for: movie.mediaKey, in: context)
    }

    /// Marking watched removes it from the Watch List — the two are mutually exclusive.
    static func setWatched(_ watched: Bool, for key: MediaKey, in context: ModelContext) {
        if watched {
            let item = upsert(key: key, in: context)
            item.watchedAt = floatingDay(from: Date())
            MediaList.watchList(in: context)?.remove(key: key)
        } else if let item = find(key: key, in: context) {
            item.watchedAt = nil
            item.pruneIfEmpty()
        }
    }
    static func setWatched(_ watched: Bool, for movie: Movie, in context: ModelContext) {
        setWatched(watched, for: movie.mediaKey, in: context)
    }

    static func recordView(key: MediaKey, in context: ModelContext, keeping limit: Int = 20) {
        upsert(key: key, in: context).lastViewedAt = Date()

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
    static func recordView(_ movie: Movie, in context: ModelContext, keeping limit: Int = 20) {
        recordView(key: movie.mediaKey, in: context, keeping: limit)
    }
}

// MARK: - Watched-date timezone

extension MediaItem {
    /// Stores a local calendar day as midnight UTC, so it reads as the same day on every device.
    static func floatingDay(from localDate: Date) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: localDate)
        return utc.date(from: comps) ?? localDate
    }

    static func localDay(from storedDate: Date) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = utc.dateComponents([.year, .month, .day], from: storedDate)
        return Calendar.current.date(from: comps) ?? storedDate
    }
}

// MARK: - De-duplication

extension MediaItem {
    /// CloudKit has no unique constraint, so sync can create duplicates to collapse.
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
                keep.sortDate = keep.sortDate ?? drop.sortDate
                keep.showWatched = keep.showWatched ?? drop.showWatched
                keep.watchListOptOut = keep.watchListOptOut ?? drop.watchListOptOut
                context.delete(drop)
            }
            changed = true
        }
        return changed
    }
}

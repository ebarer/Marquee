//
//  WatchListEntry.swift
//  MovieTracker
//
//  SwiftData model for the user's Watch List, synced via CloudKit. Each entry
//  is a lightweight snapshot of a movie (id/title/poster/release date) plus its
//  list state: `tracked` (To Watch) and `watched` (Watched). An entry that is
//  neither tracked nor watched is orphaned and gets deleted.
//
//  CloudKit requires every stored property to have a default value or be
//  optional, and forbids `@Attribute(.unique)` — so de-duplication is done by
//  fetching an existing entry for a movie id rather than a unique constraint.
//

import Foundation
import SwiftData

@Model
final class WatchListEntry {
    var movieID: Int = 0
    var title: String = ""
    var posterPath: String?
    var releaseDate: Date?
    var tracked: Bool = false      // on the "To Watch" list
    var watched: Bool = false      // on the "Watched" list
    var dateAdded: Date = Date()
    var dateWatched: Date?

    init(movie: Movie) {
        self.movieID = movie.id
        self.title = movie.title
        self.posterPath = movie.poster
        self.releaseDate = movie.releaseDate
        self.dateAdded = Date()
    }

    /// Poster URL for row artwork, matching the list-thumbnail size used elsewhere.
    func posterURL(_ size: Movie.PosterSize = .w185) -> URL? {
        TMDBWrapper.imageURL(path: posterPath, size: size.rawValue)
    }
}

// MARK: - Store helpers

/// Central place for the small set of Watch List mutations, keeping the
/// delete-if-orphaned rule in one spot. All calls run on the context's actor
/// (the main context in this app).
enum WatchListStore {
    /// The existing entry for a movie id, if any.
    static func entry(for movieID: Int, in context: ModelContext) -> WatchListEntry? {
        var descriptor = FetchDescriptor<WatchListEntry>(
            predicate: #Predicate { $0.movieID == movieID }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// The existing entry for a movie, or a freshly-inserted one.
    private static func entryOrCreate(for movie: Movie, in context: ModelContext) -> WatchListEntry {
        if let existing = entry(for: movie.id, in: context) {
            return existing
        }
        let entry = WatchListEntry(movie: movie)
        context.insert(entry)
        return entry
    }

    /// Adds or removes the movie from the To Watch list.
    static func setTracked(_ tracked: Bool, for movie: Movie, in context: ModelContext) {
        let entry = entryOrCreate(for: movie, in: context)
        entry.tracked = tracked
        if tracked { entry.watched = false; entry.dateWatched = nil }
        pruneIfOrphaned(entry, in: context)
    }

    /// Adds or removes the movie from the Watched list, stamping/clearing the
    /// watched date. Marking watched also clears the tracked flag.
    static func setWatched(_ watched: Bool, for movie: Movie, in context: ModelContext) {
        let entry = entryOrCreate(for: movie, in: context)
        entry.watched = watched
        if watched {
            entry.tracked = false
            entry.dateWatched = Date()
        } else {
            entry.dateWatched = nil
        }
        pruneIfOrphaned(entry, in: context)
    }

    /// Deletes an entry that is on neither list.
    private static func pruneIfOrphaned(_ entry: WatchListEntry, in context: ModelContext) {
        if !entry.tracked && !entry.watched {
            context.delete(entry)
        }
    }
}

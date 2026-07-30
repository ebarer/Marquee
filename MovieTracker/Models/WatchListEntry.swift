//
//  WatchListEntry.swift
//  MovieTracker
//
//  A movie's membership in one MovieList, synced via CloudKit. Each entry is a
//  lightweight snapshot of the movie (id/title/poster/release date) plus the
//  list it belongs to. A movie on N lists has N entries.
//
//  CloudKit requires every stored property to have a default or be optional and
//  forbids @Attribute(.unique) — de-duplication is done by looking through a
//  list's entries rather than a unique constraint.
//

import Foundation
import SwiftData

@Model
final class WatchListEntry {
    var movieID: Int = 0
    var title: String = ""
    var posterPath: String?
    var releaseDate: Date?
    var dateAdded: Date = Date()
    var dateWatched: Date?

    /// The list this entry belongs to (inverse of `MovieList.entries`).
    var list: MovieList?

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

/// Central place for list/membership mutations. The two built-in lists (To Watch
/// and Watched) are mutually exclusive with each other; custom lists are additive.
/// All calls run on the context's actor (the main context in this app).
enum WatchListStore {

    // MARK: Lists

    /// Ensures the two built-in lists exist with their canonical name/icon,
    /// creating any that are missing and normalizing any that already exist.
    @discardableResult
    static func ensureDefaultLists(in context: ModelContext) -> (toWatch: MovieList, watched: MovieList) {
        let toWatch = defaultList(kind: .toWatch, name: "Watch List", symbol: "bookmark", sortOrder: 0, in: context)
        let watched = defaultList(kind: .watched, name: "Watched", symbol: "checkmark.rectangle.stack", sortOrder: 1, in: context)
        return (toWatch, watched)
    }

    /// Fetches a built-in list, creating it if missing and keeping its name/icon
    /// canonical (so renames from older versions propagate on launch).
    private static func defaultList(kind: ListKind, name: String, symbol: String,
                                    sortOrder: Int, in context: ModelContext) -> MovieList {
        if let existing = list(kind: kind, in: context) {
            if existing.name != name { existing.name = name }
            if existing.symbol != symbol { existing.symbol = symbol }
            return existing
        }
        return insert(MovieList(name: name, symbol: symbol, kind: kind, sortOrder: sortOrder), in: context)
    }

    /// All lists in display order.
    static func allLists(in context: ModelContext) -> [MovieList] {
        let descriptor = FetchDescriptor<MovieList>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The built-in list of a given kind, if it exists.
    static func list(kind: ListKind, in context: ModelContext) -> MovieList? {
        let raw = kind.rawValue
        var descriptor = FetchDescriptor<MovieList>(predicate: #Predicate { $0.kindRaw == raw })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: Membership

    /// The entry for a movie within a specific list, if any.
    static func entry(for movieID: Int, in list: MovieList) -> WatchListEntry? {
        (list.entries ?? []).first { $0.movieID == movieID }
    }

    /// Whether a movie is on a given list.
    static func isMember(_ movieID: Int, of list: MovieList) -> Bool {
        entry(for: movieID, in: list) != nil
    }

    /// Adds a movie to a list. Adding to a built-in list removes the movie from
    /// the opposite built-in list (To Watch ↔ Watched); custom lists are additive.
    static func add(_ movie: Movie, to list: MovieList, in context: ModelContext) {
        switch list.kind {
        case .toWatch: removeMovie(movie.id, fromKind: .watched, in: context)
        case .watched: removeMovie(movie.id, fromKind: .toWatch, in: context)
        case .custom: break
        }

        guard entry(for: movie.id, in: list) == nil else { return }

        let entry = WatchListEntry(movie: movie)
        if list.tracksWatchedDate { entry.dateWatched = Date() }
        entry.list = list
        context.insert(entry)
    }

    /// Removes a movie from a list (no-op if it isn't on it).
    static func remove(_ movie: Movie, from list: MovieList, in context: ModelContext) {
        if let entry = entry(for: movie.id, in: list) {
            delete(entry, in: context)
        }
    }

    /// Toggles a movie's membership in a list.
    static func toggle(_ movie: Movie, in list: MovieList, in context: ModelContext) {
        if entry(for: movie.id, in: list) != nil {
            remove(movie, from: list, in: context)
        } else {
            add(movie, to: list, in: context)
        }
    }

    /// Deletes a specific entry (used by row swipe-to-remove). Clearing the
    /// relationship first updates the owning list's `entries` array immediately,
    /// so membership checks reflect the removal without waiting for a save.
    static func delete(_ entry: WatchListEntry, in context: ModelContext) {
        entry.list = nil
        context.delete(entry)
    }

    // MARK: - Private

    private static func removeMovie(_ movieID: Int, fromKind kind: ListKind, in context: ModelContext) {
        guard let list = list(kind: kind, in: context),
              let entry = entry(for: movieID, in: list) else { return }
        delete(entry, in: context)
    }

    @discardableResult
    private static func insert(_ list: MovieList, in context: ModelContext) -> MovieList {
        context.insert(list)
        return list
    }
}

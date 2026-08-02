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
    /// Stable identity used to collapse duplicate memberships deterministically
    /// (lowest UUID wins) across devices. A given membership is one shared CloudKit
    /// record with the same UUID everywhere; two independently-created memberships
    /// for the same movie have different UUIDs.
    var uuid: UUID = UUID()
    var movieID: Int = 0
    var title: String = ""
    var posterPath: String?
    var releaseDate: Date?
    var dateAdded: Date = Date()
    var dateWatched: Date?
    /// The user's personal rating in stars (0.5–5.0 in half steps, e.g. 3.5).
    /// `nil` when unrated. Only meaningful on a Watched-list entry.
    var userRating: Double?
    /// The movie's runtime in minutes, captured when the entry is created so rows
    /// can show a duration without re-fetching. `nil` for entries saved before
    /// this was tracked, or when the source movie had no runtime.
    var runtime: Int?

    /// The list this entry belongs to (inverse of `MovieList.entries`).
    var list: MovieList?

    init(movie: Movie) {
        self.uuid = UUID()
        self.movieID = movie.id
        self.title = movie.title
        self.posterPath = movie.poster
        self.releaseDate = movie.releaseDate
        self.dateAdded = Date()
        self.runtime = movie.runtime
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

    /// Ensures the built-in lists exist with their canonical name/icon, creating
    /// any that are missing and normalizing any that already exist. The Viewed
    /// list gets a high sort order so it always trails the user's custom lists.
    @discardableResult
    static func ensureDefaultLists(in context: ModelContext) -> (toWatch: MovieList, watched: MovieList) {
        // Collapse any duplicate built-in lists a prior CloudKit sync produced
        // before normalizing/recreating the canonical ones.
        deduplicateBuiltInLists(in: context)
        let toWatch = defaultList(kind: .toWatch, name: "Watch List", symbol: "bookmark", sortOrder: 0, in: context)
        let watched = defaultList(kind: .watched, name: "Watched", symbol: "checkmark.rectangle.stack", sortOrder: 1, in: context)
        _ = defaultList(kind: .viewed, name: "Viewed", symbol: "clock.arrow.circlepath", sortOrder: 1000, in: context)
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

    /// All live lists in display order (duplicates awaiting cleanup excluded).
    static func allLists(in context: ModelContext) -> [MovieList] {
        let descriptor = FetchDescriptor<MovieList>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        return ((try? context.fetch(descriptor)) ?? []).filter { !$0.isDeduplicated }
    }

    /// The canonical live list of a given kind, if it exists — the lowest-UUID
    /// copy that hasn't been marked as a duplicate. Every device agrees on it.
    static func list(kind: ListKind, in context: ModelContext) -> MovieList? {
        lists(kind: kind, in: context).first
    }

    /// Live (non-duplicate) lists of a given kind, ordered by UUID. Normally one;
    /// duplicates a prior CloudKit sync produced are excluded here and cleaned up
    /// by `deduplicateBuiltInLists`.
    static func lists(kind: ListKind, in context: ModelContext) -> [MovieList] {
        listsOfKind(kind, in: context).filter { !$0.isDeduplicated }
    }

    /// Every list of a kind, including ones already marked as duplicates, ordered
    /// by UUID so all devices pick the same canonical (first) one.
    private static func listsOfKind(_ kind: ListKind, in context: ModelContext) -> [MovieList] {
        let raw = kind.rawValue
        let descriptor = FetchDescriptor<MovieList>(predicate: #Predicate { $0.kindRaw == raw })
        let fetched = (try? context.fetch(descriptor)) ?? []
        return fetched.sorted { $0.uuid.uuidString < $1.uuid.uuidString }
    }

    /// How long a merged-away duplicate list waits before it's actually deleted,
    /// giving its entry re-parent time to sync so the delete can't race it.
    private static let deduplicationGracePeriod: TimeInterval = 30

    /// Converges duplicate built-in lists (To Watch / Watched / Viewed) to a
    /// single record per kind, safely for CloudKit. Two devices that seed their
    /// defaults before syncing each create their own built-in records; this
    /// collapses them so every device shows one list with all its movies.
    ///
    /// Runs in two phases so a list is never re-parented and deleted in the same
    /// pass:
    ///  • Merge — move every duplicate's entries onto the lowest-UUID winner,
    ///    collapse movies that now appear twice, and mark the duplicate (hiding it
    ///    from the UI). Marking, not deleting, defers the delete.
    ///  • Prune — delete a marked duplicate only once it's empty and its mark is
    ///    older than `deduplicationGracePeriod`, i.e. the entry moves have had
    ///    time to sync. Because entries are shared CloudKit records, an empty
    ///    duplicate is empty on every device, so the delete can't drop a movie.
    ///
    /// Deterministic (lowest UUID) so all devices converge identically; idempotent.
    @discardableResult
    static func deduplicateBuiltInLists(in context: ModelContext) -> Bool {
        var changed = false
        for kind in [ListKind.toWatch, .watched, .viewed] {
            let all = listsOfKind(kind, in: context)
            guard let winner = all.first(where: { !$0.isDeduplicated }) else {
                if !all.isEmpty {
                    SyncLog.logger.log("🔧 dedup kind=\(kind.rawValue): \(all.count) copies, all marked — nothing live")
                }
                continue
            }
            let duplicateCount = all.count - 1
            var movedEntries = 0
            var markedNow = 0

            // Merge: move every other copy's entries onto the winner and mark it.
            for other in all where other.persistentModelID != winner.persistentModelID {
                for moving in other.entries ?? [] {
                    moving.list = winner
                    movedEntries += 1
                    changed = true
                }
                if other.deduplicatedDate == nil {
                    other.deduplicatedDate = Date()
                    markedNow += 1
                    changed = true
                }
            }

            // Collapse movies that now appear on the winner more than once.
            if dedupeEntries(in: winner, context: context) { changed = true }

            // Prune: remove duplicates whose moves have had time to sync.
            var pruned = 0
            for duplicate in all where duplicate.isDeduplicated {
                let age = Date().timeIntervalSince(duplicate.deduplicatedDate ?? .distantFuture)
                if age > deduplicationGracePeriod, (duplicate.entries ?? []).isEmpty {
                    context.delete(duplicate)
                    pruned += 1
                    changed = true
                }
            }

            if duplicateCount > 0 || movedEntries > 0 || pruned > 0 {
                let w = String(winner.uuid.uuidString.prefix(8))
                SyncLog.logger.log("🔧 dedup kind=\(kind.rawValue): \(duplicateCount) duplicate(s), winner=\(w, privacy: .public), movedEntries=\(movedEntries), markedNow=\(markedNow), pruned=\(pruned)")
            }
        }
        if changed { try? context.save() }
        return changed
    }

    /// Collapses entries on a list that share a `movieID`, keeping the lowest-UUID
    /// entry (so every device keeps the same one) and folding the rest into it.
    @discardableResult
    private static func dedupeEntries(in list: MovieList, context: ModelContext) -> Bool {
        var changed = false
        let groups = Dictionary(grouping: list.entries ?? [], by: { $0.movieID })
        for (_, entries) in groups where entries.count > 1 {
            let ordered = entries.sorted { $0.uuid.uuidString < $1.uuid.uuidString }
            let keep = ordered[0]
            for dropped in ordered.dropFirst() {
                merge(dropped, into: keep)
                delete(dropped, in: context)
            }
            changed = true
        }
        return changed
    }

    /// Folds a duplicate entry's data into the one being kept: earliest add date
    /// wins and any field the survivor is missing is filled from the duplicate.
    private static func merge(_ dropped: WatchListEntry, into keep: WatchListEntry) {
        keep.dateAdded = min(keep.dateAdded, dropped.dateAdded)
        if keep.dateWatched == nil { keep.dateWatched = dropped.dateWatched }
        if keep.userRating == nil { keep.userRating = dropped.userRating }
        if keep.runtime == nil { keep.runtime = dropped.runtime }
        if keep.posterPath == nil { keep.posterPath = dropped.posterPath }
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

    /// The user's personal rating in stars (0.5–5.0 in half steps), if set.
    static func rating(for movieID: Int, in list: MovieList) -> Double? {
        entry(for: movieID, in: list)?.userRating
    }

    /// Sets (or clears, with `nil`/≤0) the user's personal rating for a movie on
    /// a list, in stars. Snaps to the nearest half star. No-op if the movie isn't
    /// on the list.
    static func setRating(_ stars: Double?, for movieID: Int, in list: MovieList) {
        let snapped = stars.flatMap { $0 > 0 ? ($0 * 2).rounded() / 2 : nil }
        entry(for: movieID, in: list)?.userRating = snapped
    }

    /// The date the user watched a movie on a list, if recorded.
    static func dateWatched(for movieID: Int, in list: MovieList) -> Date? {
        entry(for: movieID, in: list)?.dateWatched
    }

    /// Sets (or clears, with `nil`) the date the user watched a movie on a list.
    /// No-op if the movie isn't on the list.
    static func setDateWatched(_ date: Date?, for movieID: Int, in list: MovieList) {
        entry(for: movieID, in: list)?.dateWatched = date
    }

    /// A watched date stored canonically as midnight UTC for a calendar day, so it
    /// reads as the same day on every device regardless of timezone. Pass a date
    /// expressed in the user's local time (from a DatePicker or `Date()`); its
    /// local year/month/day is preserved.
    static func floatingDay(from localDate: Date) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: localDate)
        return utc.date(from: comps) ?? localDate
    }

    /// Converts a canonical UTC-midnight watched date back to midnight in the
    /// user's timezone, for a DatePicker/label that operates in local time.
    static func localDay(from storedDate: Date) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = utc.dateComponents([.year, .month, .day], from: storedDate)
        return Calendar.current.date(from: comps) ?? storedDate
    }

    /// Adds a movie to a list. Adding to a built-in list removes the movie from
    /// the opposite built-in list (To Watch ↔ Watched); custom lists are additive.
    static func add(_ movie: Movie, to list: MovieList, in context: ModelContext) {
        switch list.kind {
        case .toWatch: removeMovie(movie.id, fromKind: .watched, in: context)
        case .watched: removeMovie(movie.id, fromKind: .toWatch, in: context)
        case .custom, .viewed: break
        }

        guard entry(for: movie.id, in: list) == nil else { return }

        let entry = WatchListEntry(movie: movie)
        if list.tracksWatchedDate { entry.dateWatched = floatingDay(from: Date()) }
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

    /// Records that a movie's detail page was browsed, keeping the Viewed list a
    /// rotating history of the most recent `limit` movies. Re-viewing a movie
    /// already on the list moves it back to the top (by re-dating its entry), and
    /// anything past the limit is trimmed off the tail.
    static func recordView(_ movie: Movie, in context: ModelContext, keeping limit: Int = 20) {
        guard let list = list(kind: .viewed, in: context) else { return }

        // Drop any existing entry so re-viewing rotates the movie back to the top.
        if let existing = entry(for: movie.id, in: list) {
            delete(existing, in: context)
        }

        let entry = WatchListEntry(movie: movie)
        entry.list = list
        context.insert(entry)

        // Keep only the most-recently-viewed entries.
        let ordered = (list.entries ?? []).sorted { $0.dateAdded > $1.dateAdded }
        for stale in ordered.dropFirst(limit) {
            delete(stale, in: context)
        }
    }

    /// Removes every entry from a list, leaving the list itself in place. Used to
    /// clear the Viewed history.
    static func clear(_ list: MovieList, in context: ModelContext) {
        for entry in list.entries ?? [] {
            delete(entry, in: context)
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

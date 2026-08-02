//
//  MediaList.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A user-facing list of titles, synced via CloudKit. The single built-in list is
/// the Watch List (`isWatchList`); the rest are custom. Watched and Viewed are not
/// lists — they're derived from `MediaItem`. Owns its members as `ListEntry`
/// children (a self-contained, shareable tree). CloudKit-friendly: properties
/// default or optional, no unique constraints, relationships optional with inverse.
@Model
final class MediaList {
    var uuid: UUID = UUID()
    var name: String = ""
    var symbol: String = "list.bullet"
    /// Index into `Color.listPalette` for a custom list's tint.
    var colorIndex: Int = 0
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    /// Remembered per-list sort direction (moved off UserDefaults so it syncs).
    var sortAscending: Bool = true
    /// The one built-in list; can't be renamed or deleted.
    var isWatchList: Bool = false
    /// Set when a duplicate built-in has been merged away and is awaiting deletion.
    var deduplicatedDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \ListEntry.list)
    var entries: [ListEntry]? = []

    init(name: String, symbol: String = "list.bullet", sortOrder: Int = 0,
         colorIndex: Int = 0, isWatchList: Bool = false) {
        self.uuid = UUID()
        self.name = name
        self.symbol = symbol
        self.sortOrder = sortOrder
        self.colorIndex = colorIndex
        self.isWatchList = isWatchList
        self.createdAt = Date()
    }

    var isDeduplicated: Bool { deduplicatedDate != nil }
    var isEditable: Bool { !isWatchList }

    /// The Watch List carries the brand accent; custom lists their palette color.
    var color: Color { isWatchList ? .appAccent : Color.listColor(colorIndex) }

    // MARK: Membership

    func entry(for tmdbID: Int, _ mediaType: MediaType = .movie) -> ListEntry? {
        (entries ?? []).first { $0.tmdbID == tmdbID && $0.mediaTypeRaw == mediaType.rawValue }
    }

    func contains(_ tmdbID: Int, _ mediaType: MediaType = .movie) -> Bool {
        entry(for: tmdbID, mediaType) != nil
    }

    /// Adds a movie (idempotent). Adding to the Watch List un-marks Watched — the
    /// two are mutually exclusive.
    func add(_ movie: Movie) {
        guard let context = modelContext else { return }
        if entry(for: movie.id) == nil {
            let entry = ListEntry(movie: movie)
            entry.list = self
            context.insert(entry)
        }
        if isWatchList {
            MediaItem.setWatched(false, for: movie, in: context)
        }
    }

    func remove(_ movie: Movie) {
        guard let context = modelContext, let entry = entry(for: movie.id) else { return }
        context.delete(entry)
    }

    func toggle(_ movie: Movie) {
        contains(movie.id) ? remove(movie) : add(movie)
    }

    /// Collapses entries that share a title (after a merge), keeping the earliest.
    func dedupeEntries() {
        guard let context = modelContext else { return }
        let groups = Dictionary(grouping: entries ?? []) { "\($0.tmdbID)-\($0.mediaTypeRaw)" }
        for (_, dupes) in groups where dupes.count > 1 {
            for drop in dupes.sorted(by: { $0.addedAt < $1.addedAt }).dropFirst() {
                context.delete(drop)
            }
        }
    }
}

// MARK: - Fetch / seed / dedup

extension MediaList {
    /// All live lists (duplicates awaiting cleanup excluded), in display order.
    static func all(in context: ModelContext) -> [MediaList] {
        let descriptor = FetchDescriptor<MediaList>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        return ((try? context.fetch(descriptor)) ?? []).filter { !$0.isDeduplicated }
    }

    static func customLists(in context: ModelContext) -> [MediaList] {
        all(in: context).filter { !$0.isWatchList }
    }

    /// The canonical Watch List (lowest-UUID live copy), if it exists.
    static func watchList(in context: ModelContext) -> MediaList? {
        ((try? context.fetch(FetchDescriptor<MediaList>())) ?? [])
            .filter { $0.isWatchList && !$0.isDeduplicated }
            .sorted { $0.uuid.uuidString < $1.uuid.uuidString }
            .first
    }

    /// Creates the Watch List if missing (seeded at launch).
    @discardableResult
    static func ensureWatchList(in context: ModelContext) -> MediaList {
        if let existing = watchList(in: context) { return existing }
        let list = MediaList(name: "Watch List", symbol: "bookmark", sortOrder: 0, isWatchList: true)
        context.insert(list)
        return list
    }

    /// Converges duplicate Watch Lists a CloudKit sync produced onto the lowest-UUID
    /// copy, moving entries over. Deterministic so every device agrees.
    @discardableResult
    static func deduplicateWatchList(in context: ModelContext) -> Bool {
        let watchLists = ((try? context.fetch(FetchDescriptor<MediaList>())) ?? [])
            .filter { $0.isWatchList }
            .sorted { $0.uuid.uuidString < $1.uuid.uuidString }
        guard let keep = watchLists.first, watchLists.count > 1 else { return false }
        for dup in watchLists.dropFirst() {
            for entry in dup.entries ?? [] { entry.list = keep }
            context.delete(dup)
        }
        keep.dedupeEntries()
        return true
    }
}

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
    /// All canonical lists in display order: duplicates awaiting cleanup excluded and
    /// any duplicate live Watch List collapsed to the canonical copy.
    static func all(in context: ModelContext) -> [MediaList] {
        let descriptor = FetchDescriptor<MediaList>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        let live = ((try? context.fetch(descriptor)) ?? []).filter { !$0.isDeduplicated }
        guard let canonicalWatch = watchList(in: context) else { return live }
        return live.filter { !$0.isWatchList || $0.uuid == canonicalWatch.uuid }
    }

    static func customLists(in context: ModelContext) -> [MediaList] {
        all(in: context).filter { !$0.isWatchList }
    }

    /// The canonical Watch List (the oldest live copy; UUID breaks ties), if it
    /// exists. Must match the de-dup winner so adds never target a soon-to-be-merged
    /// duplicate.
    static func watchList(in context: ModelContext) -> MediaList? {
        ((try? context.fetch(FetchDescriptor<MediaList>())) ?? [])
            .filter { $0.isWatchList && !$0.isDeduplicated }
            .sorted { ($0.createdAt, $0.uuid.uuidString) < ($1.createdAt, $1.uuid.uuidString) }
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

    /// How long a merged-away duplicate waits before it's actually deleted, so its
    /// entry re-parent has time to sync and the delete can't race it.
    private static let deduplicationGracePeriod: TimeInterval = 30

    /// Converges duplicate Watch Lists onto the oldest (UUID breaks ties) so every
    /// device agrees. Two-phase, CloudKit-safe:
    ///  - **Merge:** re-parent each duplicate's entries onto the winner, then mark
    ///    the duplicate (hidden via `isDeduplicated`) — not deleted yet.
    ///  - **Prune:** delete a marked duplicate only once empty and past the grace
    ///    period, by when the re-parent has converged so the cascade drops nothing.
    ///    Deleting sooner could wipe entries on a device that applies the delete
    ///    before the re-parent arrives.
    @discardableResult
    static func deduplicateWatchList(in context: ModelContext) -> Bool {
        let watchLists = ((try? context.fetch(FetchDescriptor<MediaList>())) ?? [])
            .filter { $0.isWatchList }
            .sorted { ($0.createdAt, $0.uuid.uuidString) < ($1.createdAt, $1.uuid.uuidString) }
        guard let keep = watchLists.first(where: { !$0.isDeduplicated }) else { return false }
        var changed = false
        var merged = false

        // Merge live duplicates onto the winner, then mark them.
        for other in watchLists where other.uuid != keep.uuid && !other.isDeduplicated {
            for entry in other.entries ?? [] { entry.list = keep; merged = true }
            other.deduplicatedDate = Date()
            changed = true
        }
        if merged { keep.dedupeEntries() }

        // Prune marked duplicates once empty and past the grace period.
        for dup in watchLists where dup.isDeduplicated {
            let age = Date().timeIntervalSince(dup.deduplicatedDate ?? .distantFuture)
            if age > deduplicationGracePeriod, (dup.entries ?? []).isEmpty {
                context.delete(dup)
                changed = true
            }
        }
        return changed
    }
}

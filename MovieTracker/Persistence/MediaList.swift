//
//  MediaList.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A user-facing list of titles owning `ListEntry` children. CloudKit-friendly:
/// properties default or optional, no unique constraints, relationships have inverses.
@Model
final class MediaList {
    var uuid: UUID = UUID()
    var name: String = ""
    var symbol: String = "list.bullet"
    var colorIndex: Int = 0
    var customColorHex: String?
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var sortAscending: Bool = true
    var sortKeyRaw: String = ListSortKey.releaseDate.rawValue
    var isWatchList: Bool = false
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

    var sortKey: ListSortKey {
        get { ListSortKey(rawValue: sortKeyRaw) ?? .releaseDate }
        set { sortKeyRaw = newValue.rawValue }
    }

    var color: Color {
        if isWatchList { return .appAccent }
        if let hex = customColorHex, let custom = Color(hex: hex) { return custom }
        return Color.listColor(colorIndex)
    }

    // MARK: Membership

    func entry(for tmdbID: Int, _ mediaType: MediaType = .movie) -> ListEntry? {
        (entries ?? []).first { $0.tmdbID == tmdbID && $0.mediaTypeRaw == mediaType.rawValue }
    }

    func contains(_ tmdbID: Int, _ mediaType: MediaType = .movie) -> Bool {
        entry(for: tmdbID, mediaType) != nil
    }

    /// Adding to the Watch List un-marks Watched — the two are mutually exclusive.
    func add(key: MediaKey) {
        guard let context = modelContext else { return }
        if entry(for: key.tmdbID, key.mediaType) == nil {
            let entry = ListEntry(key: key)
            entry.list = self
            context.insert(entry)
        }
        if isWatchList {
            MediaItem.setWatched(false, for: key, in: context)
        }
    }

    func remove(key: MediaKey) {
        guard let context = modelContext,
              let entry = entry(for: key.tmdbID, key.mediaType) else { return }
        context.delete(entry)
    }

    func toggle(key: MediaKey) {
        contains(key.tmdbID, key.mediaType) ? remove(key: key) : add(key: key)
    }

    func add(_ movie: Movie) { add(key: movie.mediaKey) }
    func remove(_ movie: Movie) { remove(key: movie.mediaKey) }
    func toggle(_ movie: Movie) { toggle(key: movie.mediaKey) }

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

    /// Must match the de-dup winner so adds never target a soon-to-be-merged duplicate.
    static func watchList(in context: ModelContext) -> MediaList? {
        ((try? context.fetch(FetchDescriptor<MediaList>())) ?? [])
            .filter { $0.isWatchList && !$0.isDeduplicated }
            .sorted { ($0.createdAt, $0.uuid.uuidString) < ($1.createdAt, $1.uuid.uuidString) }
            .first
    }

    @discardableResult
    static func ensureWatchList(in context: ModelContext) -> MediaList {
        if let existing = watchList(in: context) { return existing }
        let list = MediaList(name: "Watch List", symbol: "bookmark", sortOrder: 0, isWatchList: true)
        context.insert(list)
        return list
    }

    /// Grace before a merged-away duplicate is deleted, so its entry re-parent syncs first.
    private static let deduplicationGracePeriod: TimeInterval = 30

    /// Two-phase, CloudKit-safe: re-parent duplicates' entries onto the winner and mark
    /// them, then delete only once empty and past the grace period — deleting sooner
    /// could wipe entries on a device that applies the delete before the re-parent arrives.
    @discardableResult
    static func deduplicateWatchList(in context: ModelContext) -> Bool {
        let watchLists = ((try? context.fetch(FetchDescriptor<MediaList>())) ?? [])
            .filter { $0.isWatchList }
            .sorted { ($0.createdAt, $0.uuid.uuidString) < ($1.createdAt, $1.uuid.uuidString) }
        guard let keep = watchLists.first(where: { !$0.isDeduplicated }) else { return false }
        var changed = false
        var merged = false

        for other in watchLists where other.uuid != keep.uuid && !other.isDeduplicated {
            for entry in other.entries ?? [] { entry.list = keep; merged = true }
            other.deduplicatedDate = Date()
            changed = true
        }
        if merged { keep.dedupeEntries() }

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

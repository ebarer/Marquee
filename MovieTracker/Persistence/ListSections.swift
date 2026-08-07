//
//  ListSections.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// What a section build reads.
enum SectionSource: Sendable, Equatable {
    case list(UUID, byDateAdded: Bool)
    case watched(byWatchedDate: Bool)
    case viewed
}

/// A Sendable snapshot of a row, handed from the background build context to the UI.
struct MediaSnapshot: Identifiable, Sendable, Equatable {
    let persistentID: PersistentIdentifier
    let tmdbID: Int
    let title: String
    let posterPath: String?
    let releaseDate: Date?
    let runtime: Int?
    let dateWatched: Date?
    let userRating: Double?

    var id: PersistentIdentifier { persistentID }
}

struct SectionSnapshot: Identifiable, Sendable, Equatable {
    let id: DateComponents
    let title: String
    let entries: [MediaSnapshot]
    /// True for the "Older" archive bucket, which the list renders collapsed.
    let isCollapsible: Bool

    /// Sentinel id for the "Older" section; the negative year never collides with a
    /// real `[.year, .month]` key.
    static let olderID = DateComponents(year: -1, month: -1)
}

/// Builds a source's month/year sections on a background context.
@ModelActor
actor SectionBuilder {
    func build(source: SectionSource, ascending: Bool, filter: String) -> [SectionSnapshot] {
        switch source {
        case .list(let listID, let byDateAdded):
            return buildList(listID, byDateAdded: byDateAdded, ascending: ascending, filter: filter)
        case .watched(let byWatchedDate):
            return buildWatched(byWatchedDate: byWatchedDate, ascending: ascending, filter: filter)
        case .viewed:
            return buildViewed(ascending: ascending, filter: filter)
        }
    }

    // MARK: List membership (ListEntry)

    private func buildList(_ listID: UUID, byDateAdded: Bool, ascending: Bool, filter: String) -> [SectionSnapshot] {
        let descriptor = FetchDescriptor<ListEntry>(
            predicate: #Predicate { $0.list?.uuid == listID }
        )
        guard let entries = try? modelContext.fetch(descriptor) else { return [] }

        let items = (try? modelContext.fetch(FetchDescriptor<MediaItem>())) ?? []
        var factsByID: [Int: (rating: Double?, watched: Date?)] = [:]
        for item in items { factsByID[item.tmdbID] = (item.userRating, item.watchedAt) }

        let filtered = filter.isEmpty
            ? entries
            : entries.filter { $0.title.localizedCaseInsensitiveContains(filter) }

        let dated = filtered.map { entry -> (date: Date, snapshot: MediaSnapshot) in
            let facts = factsByID[entry.tmdbID]
            let date = byDateAdded ? entry.addedAt : (entry.releaseDate ?? .distantFuture)
            return (date,
                    MediaSnapshot(persistentID: entry.persistentModelID,
                                  tmdbID: entry.tmdbID, title: entry.title,
                                  posterPath: entry.posterPath, releaseDate: entry.releaseDate,
                                  runtime: entry.runtime, dateWatched: facts?.watched,
                                  userRating: facts?.rating))
        }
        if byDateAdded { return flat(dated, ascending: ascending) }
        // Only the Watch List folds stale titles into an "Older" bucket; custom
        // lists keep every month section live.
        let isWatchList = entries.first?.list?.isWatchList ?? false
        return group(dated, ascending: ascending, foldOlderThan: isWatchList ? olderCutoff() : nil)
    }

    // MARK: Derived Watched (MediaItem, grouped by month)

    private func buildWatched(byWatchedDate: Bool, ascending: Bool, filter: String) -> [SectionSnapshot] {
        let descriptor = FetchDescriptor<MediaItem>(predicate: #Predicate { $0.watchedAt != nil })
        guard let items = try? modelContext.fetch(descriptor) else { return [] }

        let filtered = filter.isEmpty
            ? items
            : items.filter { $0.title.localizedCaseInsensitiveContains(filter) }

        let dated = filtered.map { item -> (date: Date, snapshot: MediaSnapshot) in
            let date = byWatchedDate ? (item.watchedAt ?? .distantFuture) : (item.releaseDate ?? .distantFuture)
            return (date, snapshot(from: item))
        }
        return group(dated, ascending: ascending)
    }

    // MARK: Derived Viewed (MediaItem, flat recency — no grouping)

    private func buildViewed(ascending: Bool, filter: String) -> [SectionSnapshot] {
        let descriptor = FetchDescriptor<MediaItem>(predicate: #Predicate { $0.lastViewedAt != nil })
        guard let items = try? modelContext.fetch(descriptor) else { return [] }

        let filtered = filter.isEmpty
            ? items
            : items.filter { $0.title.localizedCaseInsensitiveContains(filter) }

        let sorted = filtered.sorted { ($0.lastViewedAt ?? .distantPast) < ($1.lastViewedAt ?? .distantPast) }
        let ordered = ascending ? sorted : Array(sorted.reversed())
        let snapshots = ordered.map(snapshot(from:))
        return snapshots.isEmpty ? [] : [SectionSnapshot(id: DateComponents(), title: "", entries: snapshots, isCollapsible: false)]
    }

    private func snapshot(from item: MediaItem) -> MediaSnapshot {
        MediaSnapshot(persistentID: item.persistentModelID, tmdbID: item.tmdbID, title: item.title,
                      posterPath: item.posterPath, releaseDate: item.releaseDate, runtime: item.runtime,
                      dateWatched: item.watchedAt, userRating: item.userRating)
    }

    // MARK: Grouping

    private func flat(_ dated: [(date: Date, snapshot: MediaSnapshot)],
                      ascending: Bool) -> [SectionSnapshot] {
        let sorted = dated.sorted { $0.date < $1.date }
        let ordered = ascending ? sorted : Array(sorted.reversed())
        let snapshots = ordered.map(\.snapshot)
        return snapshots.isEmpty ? [] : [SectionSnapshot(id: DateComponents(), title: "", entries: snapshots, isCollapsible: false)]
    }

    /// Start of last month. Release dates before this fold into the collapsed
    /// "Older" bucket; the whole current and previous month stay live. Relative to
    /// now, so the window slides forward each month.
    private func olderCutoff() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        return calendar.date(byAdding: .month, value: -1, to: startOfMonth) ?? startOfMonth
    }

    /// Groups by month/year. When `cutoff` is set, entries dated before it are pulled
    /// out of the month sections and appended as one collapsible "Older" bucket at the
    /// bottom, regardless of sort direction (it reads as an archive).
    private func group(_ dated: [(date: Date, snapshot: MediaSnapshot)],
                       ascending: Bool, foldOlderThan cutoff: Date? = nil) -> [SectionSnapshot] {
        var recent = dated
        var older: [MediaSnapshot] = []
        if let cutoff {
            recent = dated.filter { $0.date >= cutoff }
            let olderSorted = dated.filter { $0.date < cutoff }.sorted { $0.date < $1.date }
            older = (ascending ? olderSorted : Array(olderSorted.reversed())).map(\.snapshot)
        }

        let sorted = recent.sorted { $0.date < $1.date }
        let ordered = ascending ? sorted : Array(sorted.reversed())

        let calendar = Calendar.current
        let headerFormatter = DateFormatter.sectionHeader
        var result: [SectionSnapshot] = []
        var currentKey: DateComponents?
        var currentTitle = ""
        var currentEntries: [MediaSnapshot] = []

        func flush() {
            guard let key = currentKey else { return }
            result.append(SectionSnapshot(id: key, title: currentTitle, entries: currentEntries,
                                          isCollapsible: false))
        }

        for item in ordered {
            let key = calendar.dateComponents([.year, .month], from: item.date)
            if key == currentKey {
                currentEntries.append(item.snapshot)
            } else {
                flush()
                currentKey = key
                currentTitle = calendar.date(from: key).map { headerFormatter.string(from: $0) } ?? "Unknown"
                currentEntries = [item.snapshot]
            }
        }
        flush()

        if !older.isEmpty {
            let olderSection = SectionSnapshot(id: SectionSnapshot.olderID, title: "Older",
                                               entries: older, isCollapsible: true)
            // Chronological placement: oldest-first (ascending) leads with the archive;
            // newest-first (descending) parks it at the bottom.
            if ascending { result.insert(olderSection, at: 0) } else { result.append(olderSection) }
        }
        return result
    }
}

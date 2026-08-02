//
//  ListSections.swift
//  MovieTracker
//
//  Off-main-thread section building for the Lists screen. Fetching and grouping a
//  large list (and the SwiftData faulting they trigger) runs on a background
//  context and returns Sendable snapshots; rows render entirely from those.
//

import Foundation
import SwiftData

/// What a section build reads: a list's `ListEntry` members, or the derived
/// Watched / Viewed queries over `MediaItem`.
enum SectionSource: Sendable, Equatable {
    case list(UUID)
    /// Watched titles, grouped by watched date when `byWatchedDate`, else release.
    case watched(byWatchedDate: Bool)
    case viewed
}

/// A Sendable snapshot of a row, safe to hand from the background build context to
/// the main-actor UI. `persistentID` is the `ListEntry` (for list rows) or the
/// `MediaItem` (for Watched/Viewed), used to act on the live model.
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

/// A month/year group of snapshots, e.g. "May 2025".
struct SectionSnapshot: Identifiable, Sendable, Equatable {
    let id: DateComponents
    let title: String
    let entries: [MediaSnapshot]
}

/// Builds a source's month/year sections on a background context.
@ModelActor
actor SectionBuilder {
    func build(source: SectionSource, ascending: Bool, filter: String) -> [SectionSnapshot] {
        switch source {
        case .list(let listID):
            return buildList(listID, ascending: ascending, filter: filter)
        case .watched(let byWatchedDate):
            return buildWatched(byWatchedDate: byWatchedDate, ascending: ascending, filter: filter)
        case .viewed:
            return buildViewed(ascending: ascending, filter: filter)
        }
    }

    // MARK: List membership (ListEntry)

    private func buildList(_ listID: UUID, ascending: Bool, filter: String) -> [SectionSnapshot] {
        let descriptor = FetchDescriptor<ListEntry>(
            predicate: #Predicate { $0.list?.uuid == listID }
        )
        guard let entries = try? modelContext.fetch(descriptor) else { return [] }

        // Personal facts (rating / watched date) for the rows, joined by tmdbID.
        let items = (try? modelContext.fetch(FetchDescriptor<MediaItem>())) ?? []
        var factsByID: [Int: (rating: Double?, watched: Date?)] = [:]
        for item in items { factsByID[item.tmdbID] = (item.userRating, item.watchedAt) }

        let filtered = filter.isEmpty
            ? entries
            : entries.filter { $0.title.localizedCaseInsensitiveContains(filter) }

        let dated = filtered.map { entry -> (date: Date, snapshot: MediaSnapshot) in
            let facts = factsByID[entry.tmdbID]
            return (entry.releaseDate ?? .distantFuture,
                    MediaSnapshot(persistentID: entry.persistentModelID,
                                  tmdbID: entry.tmdbID, title: entry.title,
                                  posterPath: entry.posterPath, releaseDate: entry.releaseDate,
                                  runtime: entry.runtime, dateWatched: facts?.watched,
                                  userRating: facts?.rating))
        }
        return group(dated, ascending: ascending)
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
        return snapshots.isEmpty ? [] : [SectionSnapshot(id: DateComponents(), title: "", entries: snapshots)]
    }

    private func snapshot(from item: MediaItem) -> MediaSnapshot {
        MediaSnapshot(persistentID: item.persistentModelID, tmdbID: item.tmdbID, title: item.title,
                      posterPath: item.posterPath, releaseDate: item.releaseDate, runtime: item.runtime,
                      dateWatched: item.watchedAt, userRating: item.userRating)
    }

    // MARK: Grouping

    private func group(_ dated: [(date: Date, snapshot: MediaSnapshot)],
                       ascending: Bool) -> [SectionSnapshot] {
        let sorted = dated.sorted { $0.date < $1.date }
        let ordered = ascending ? sorted : Array(sorted.reversed())

        let calendar = Calendar.current
        let headerFormatter = DateFormatter.sectionHeader
        var result: [SectionSnapshot] = []
        var currentKey: DateComponents?
        var currentTitle = ""
        var currentEntries: [MediaSnapshot] = []

        func flush() {
            guard let key = currentKey else { return }
            result.append(SectionSnapshot(id: key, title: currentTitle, entries: currentEntries))
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
        return result
    }
}

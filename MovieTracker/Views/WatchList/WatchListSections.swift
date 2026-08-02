//
//  WatchListSections.swift
//  MovieTracker
//
//  Off-main-thread section building for the Watch List. A large list (e.g. ~700
//  Watched entries) is expensive to group on the main thread because touching the
//  entries relationship faults every model in. `SectionBuilder` does the fetch and
//  grouping on a background context and returns Sendable value snapshots, so the
//  main thread never blocks. Rows render entirely from these snapshots; the live
//  `WatchListEntry` is only refetched (by its persistent id) when a row is deleted.
//

import Foundation
import SwiftData

/// Which stored date a list orders and groups its rows by.
enum EntrySortField: Sendable {
    /// Viewed history — ordered by when the movie was browsed.
    case dateAdded
    /// Watched, sorted by the date the movie was seen.
    case dateWatched
    /// Everything else — the movie's release date.
    case releaseDate
}

/// A Sendable snapshot of a `WatchListEntry`, safe to hand from the background
/// build context to the main-actor UI. Identified by the entry's persistent id so
/// rows keep stable identity and deletion can refetch the live model.
struct EntrySnapshot: Identifiable, Sendable, Equatable {
    let persistentID: PersistentIdentifier
    let movieID: Int
    let title: String
    let posterPath: String?
    let releaseDate: Date?
    let runtime: Int?
    let dateWatched: Date?
    let userRating: Double?

    var id: PersistentIdentifier { persistentID }
}

/// A month/year group of entry snapshots, e.g. "May 2025".
struct SectionSnapshot: Identifiable, Sendable, Equatable {
    let id: DateComponents
    let title: String
    let entries: [EntrySnapshot]
}

/// Builds a list's month/year sections on a background context so the grouping —
/// and, crucially, the SwiftData faulting it triggers — stays off the main thread.
@ModelActor
actor SectionBuilder {
    /// Fetches the entries belonging to `listID`, filters by `filter`, orders them
    /// by `sortField`, and groups the ordered run into month/year sections.
    func build(listID: UUID,
               sortField: EntrySortField,
               ascending: Bool,
               filter: String) -> [SectionSnapshot] {
        // One batched fetch materializes the whole list at once, rather than the
        // per-object faulting a relationship walk on the main thread would cause.
        let descriptor = FetchDescriptor<WatchListEntry>(
            predicate: #Predicate { $0.list?.uuid == listID }
        )
        guard let entries = try? modelContext.fetch(descriptor) else { return [] }

        let filtered = filter.isEmpty
            ? entries
            : entries.filter { $0.title.localizedCaseInsensitiveContains(filter) }

        // Read each entry's sort date once, then order by it — no repeated model
        // reads during the sort or the grouping below. Missing dates sort last.
        func sortDate(_ entry: WatchListEntry) -> Date {
            switch sortField {
            case .dateAdded: return entry.dateAdded
            case .dateWatched: return entry.dateWatched ?? .distantFuture
            case .releaseDate: return entry.releaseDate ?? .distantFuture
            }
        }

        let dated = filtered.map { (entry: $0, date: sortDate($0)) }
        let sorted = dated.sorted { $0.date < $1.date }
        let ordered = ascending ? sorted : Array(sorted.reversed())

        // Walk the ordered entries into month runs, starting a new section whenever
        // the year/month changes and formatting each header once.
        let calendar = Calendar.current
        let headerFormatter = DateFormatter.sectionHeader
        var result: [SectionSnapshot] = []
        var currentKey: DateComponents?
        var currentTitle = ""
        var currentEntries: [EntrySnapshot] = []

        func flush() {
            guard let key = currentKey else { return }
            result.append(SectionSnapshot(id: key, title: currentTitle, entries: currentEntries))
        }

        for item in ordered {
            let key = calendar.dateComponents([.year, .month], from: item.date)
            let snapshot = EntrySnapshot(
                persistentID: item.entry.persistentModelID,
                movieID: item.entry.movieID,
                title: item.entry.title,
                posterPath: item.entry.posterPath,
                releaseDate: item.entry.releaseDate,
                runtime: item.entry.runtime,
                dateWatched: item.entry.dateWatched,
                userRating: item.entry.userRating
            )
            if key == currentKey {
                currentEntries.append(snapshot)
            } else {
                flush()
                currentKey = key
                currentTitle = calendar.date(from: key).map { headerFormatter.string(from: $0) } ?? "Unknown"
                currentEntries = [snapshot]
            }
        }
        flush()
        return result
    }
}

//
//  SectionFormatter.swift
//  MovieTracker
//

import Foundation

/// Arranges a `ListResult` (raw dated rows + a layout) into the Lists screen's titled sections:
/// month/year grouping, the collapsed "Older" fold, and rating-star buckets. Pure — no store.
enum SectionFormatter {
    static func sections(from list: ListResult, ascending: Bool) -> [SectionSnapshot] {
        switch list.layout {
        case .flat:
            return flat(list.rows, ascending: ascending)
        case .months(let foldOlder):
            return grouped(list.rows, ascending: ascending, foldOlder: foldOlder)
        case .ratingStars:
            return byRating(list.rows, ascending: ascending)
        }
    }

    // MARK: Flat

    private static func flat(_ rows: [DatedRow], ascending: Bool) -> [SectionSnapshot] {
        let sorted = rows.sorted { $0.date < $1.date }
        let ordered = ascending ? sorted : Array(sorted.reversed())
        let snapshots = ordered.map(\.snapshot)
        return snapshots.isEmpty ? []
            : [SectionSnapshot(id: DateComponents(), title: "", entries: snapshots, isCollapsible: false)]
    }

    // MARK: Rating buckets

    /// Buckets rows by half-star steps (0…10). Each distinct rating is one section, ordered by
    /// stars; within a bucket the newest anchor date leads.
    private static func byRating(_ rows: [DatedRow], ascending: Bool) -> [SectionSnapshot] {
        var buckets: [Int: [DatedRow]] = [:]
        for row in rows {
            let rating = row.snapshot.userRating ?? 0
            let steps = rating > 0 ? Int((rating * 2).rounded()) : 0
            buckets[steps, default: []].append(row)
        }
        let keys = buckets.keys.sorted()
        let ordered = ascending ? keys : keys.reversed().map { $0 }
        return ordered.map { steps in
            let entries = buckets[steps]!.sorted { $0.date > $1.date }.map(\.snapshot)
            // The +9000 offset can't collide with month keys. Rated sections carry a star value
            // for the header; "Unrated" (0) shows text.
            return SectionSnapshot(id: DateComponents(year: 9000 + steps),
                                   title: ratingTitle(steps), entries: entries, isCollapsible: false,
                                   ratingStars: steps > 0 ? Double(steps) / 2 : nil)
        }
    }

    private static func ratingTitle(_ halfSteps: Int) -> String {
        guard halfSteps > 0 else { return "Unrated" }
        let stars = Double(halfSteps) / 2
        let text = stars == stars.rounded() ? String(format: "%.0f", stars) : String(format: "%.1f", stars)
        return "\(text) \(halfSteps == 2 ? "Star" : "Stars")"
    }

    // MARK: Month/year grouping (+ "Older" fold)

    /// See `grouped`: only fold when there's a meaningful recent block to keep on screen
    /// (>= `foldMinRecent`) and a backlog large enough to be worth hiding (>= `foldMinOlder`).
    private static let foldMinRecent = 2
    private static let foldMinOlder = 3

    /// Start of last month; entries dated before it fold into "Older". Relative to now, so the
    /// window slides forward each month.
    private static func olderCutoff() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        return calendar.date(byAdding: .month, value: -1, to: startOfMonth) ?? startOfMonth
    }

    /// Groups by month/year. When folding, entries before the cutoff are pulled out and appended
    /// as one collapsible "Older" bucket at the bottom (top when ascending — it reads as an archive).
    private static func grouped(_ rows: [DatedRow], ascending: Bool, foldOlder: Bool) -> [SectionSnapshot] {
        var recent = rows
        var older: [MediaSnapshot] = []
        if foldOlder {
            let cutoff = olderCutoff()
            let recentSplit = rows.filter { $0.date >= cutoff }
            let olderSplit = rows.filter { $0.date < cutoff }
            if recentSplit.count >= foldMinRecent && olderSplit.count >= foldMinOlder {
                recent = recentSplit
                let olderSorted = olderSplit.sorted { $0.date < $1.date }
                older = (ascending ? olderSorted : Array(olderSorted.reversed())).map(\.snapshot)
            }
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

        for row in ordered {
            let key = calendar.dateComponents([.year, .month], from: row.date)
            if key == currentKey {
                currentEntries.append(row.snapshot)
            } else {
                flush()
                currentKey = key
                currentTitle = calendar.date(from: key).map { headerFormatter.string(from: $0) } ?? "Unknown"
                currentEntries = [row.snapshot]
            }
        }
        flush()

        if !older.isEmpty {
            let olderSection = SectionSnapshot(id: SectionSnapshot.olderID, title: "Older",
                                               entries: older, isCollapsible: true)
            if ascending { result.insert(olderSection, at: 0) } else { result.append(olderSection) }
        }
        return result
    }
}

// MARK: - Convenience

extension PersistenceCoordinator {
    /// Load a feed and format it into display sections in one call — the entry point the Lists
    /// screen and tests use. Bridges the persistence read (`feed`) and the presentation formatter.
    func sections(for request: ListRequest, ascending: Bool, filter: String,
                  mediaFilter: MediaTypeFilter = .all) async -> [SectionSnapshot] {
        let list = await list(for: request, filter: filter, mediaFilter: mediaFilter)
        return SectionFormatter.sections(from: list, ascending: ascending)
    }
}

//
//  SectionFormatter.swift
//  MovieTracker
//

import Foundation

/// Arranges a `ListResult` into the Lists screen's titled sections. Pure, with no store access.
enum SectionFormatter {
    static func sections(from list: ListResult, ascending: Bool) -> [SectionSnapshot] {
        switch list.layout {
        case .flat:
            return flat(list.rows, ascending: ascending)
        case .months(let foldOlder):
            return grouped(list.rows, ascending: ascending, foldOlder: foldOlder)
        case .ratingStars:
            return byRating(list.rows, ascending: ascending)
        case .initials:
            return byInitial(list.rows, ascending: ascending)
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

    // MARK: Initial-letter buckets

    // Bucketing rather than grouping a sorted run keeps one section per letter however collation orders titles.
    private static func byInitial(_ rows: [DatedRow], ascending: Bool) -> [SectionSnapshot] {
        var buckets: [String: [(key: String, row: DatedRow)]] = [:]
        for row in rows {
            let key = sortTitle(row.snapshot.title)
            buckets[initial(of: key), default: []].append((key, row))
        }
        let keys = buckets.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let ordered = ascending ? keys : Array(keys.reversed())
        return ordered.map { letter in
            let sorted = buckets[letter]!.sorted {
                $0.key.localizedStandardCompare($1.key) == .orderedAscending
            }
            let entries = (ascending ? sorted : Array(sorted.reversed())).map(\.row.snapshot)
            // Keying off the letter's scalar with an 8000 offset can't collide with month keys
            // or the 9000+ rating ones.
            let id = DateComponents(year: 8000 + Int(letter.unicodeScalars.first?.value ?? 0))
            return SectionSnapshot(id: id, title: letter, entries: entries, isCollapsible: false)
        }
    }

    private static let leadingArticles: Set<String> = ["a", "an", "the"]

    // A title that is only an article keeps it, so "The" still sorts and files as itself.
    static func sortTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let space = trimmed.firstIndex(where: \.isWhitespace),
              leadingArticles.contains(trimmed[trimmed.startIndex..<space].lowercased()) else { return trimmed }
        let rest = trimmed[space...].trimmingCharacters(in: .whitespacesAndNewlines)
        return rest.isEmpty ? trimmed : rest
    }

    private static func initial(of title: String) -> String {
        guard let first = title.first(where: { !$0.isWhitespace }), first.isLetter else { return "#" }
        return String(first)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
    }

    // MARK: Month/year grouping (+ "Older" fold)

    // Only fold when enough rows stay on screen and the backlog is large enough to be worth hiding.
    private static let foldMinRecent = 2
    private static let foldMinOlder = 3

    // Relative to now, so the window slides forward each month.
    private static func olderCutoff() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        return calendar.date(byAdding: .month, value: -1, to: startOfMonth) ?? startOfMonth
    }

    private static func grouped(_ rows: [DatedRow], ascending: Bool, foldOlder: OlderFold) -> [SectionSnapshot] {
        var recent = rows
        var older: [MediaSnapshot] = []
        if !foldOlder.isEmpty {
            let cutoff = olderCutoff()
            let folds = { (row: DatedRow) in row.date < cutoff && foldOlder.folds(row.snapshot.mediaType) }
            let recentSplit = rows.filter { !folds($0) }
            let olderSplit = rows.filter(folds)
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
    // Both halves run off the main thread, so nothing lands on the main actor but the finished sections.
    func sections(for request: ListRequest, ascending: Bool, filter: String,
                  mediaFilter: MediaTypeFilter = .all) async -> [SectionSnapshot] {
        await readingOffMain {
            $0.sections(request: request, ascending: ascending,
                        filter: filter, mediaFilter: mediaFilter)
        }
    }
}

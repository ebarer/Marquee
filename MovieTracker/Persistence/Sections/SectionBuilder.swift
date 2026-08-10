//
//  SectionBuilder.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// Builds a source's month/year sections on a background context.
@ModelActor
actor SectionBuilder {
    func build(source: SectionSource, ascending: Bool, filter: String,
               mediaFilter: MediaTypeFilter = .all) -> [SectionSnapshot] {
        let sections: [SectionSnapshot]
        switch source {
        case .list(let listID, let byDateAdded, let foldOlder):
            sections = buildList(listID, byDateAdded: byDateAdded, foldOlder: foldOlder, ascending: ascending, filter: filter)
        case .watched(let sort):
            sections = buildWatched(sort: sort, ascending: ascending, filter: filter)
        case .viewed:
            sections = buildViewed(ascending: ascending, filter: filter)
        }
        return applyMediaFilter(sections, mediaFilter)
    }

    /// Drop entries that don't match the media-type filter, then any section left empty.
    private func applyMediaFilter(_ sections: [SectionSnapshot],
                                  _ mediaFilter: MediaTypeFilter) -> [SectionSnapshot] {
        guard mediaFilter != .all else { return sections }
        return sections.compactMap { section in
            let entries = section.entries.filter { mediaFilter.matches($0.mediaType) }
            guard !entries.isEmpty else { return nil }
            return SectionSnapshot(id: section.id, title: section.title,
                                   entries: entries, isCollapsible: section.isCollapsible)
        }
    }

    // MARK: List membership (ListEntry)

    private func buildList(_ listID: UUID, byDateAdded: Bool, foldOlder: Bool, ascending: Bool, filter: String) -> [SectionSnapshot] {
        let descriptor = FetchDescriptor<ListEntry>(
            predicate: #Predicate { $0.list?.uuid == listID }
        )
        guard let entries = try? modelContext.fetch(descriptor) else { return [] }

        // Only the Watch List represents a show by its tracked season; custom lists show
        // the whole show (seasons belong to the Watch List / Watched).
        let isWatchList = entries.first?.list?.isWatchList ?? false

        let items = (try? modelContext.fetch(FetchDescriptor<MediaItem>())) ?? []
        // Key facts by (tmdbID, mediaType) so a movie and show sharing a tmdbID don't collide.
        var factsByKey: [String: (rating: Double?, watched: Date?)] = [:]
        for item in items { factsByKey["\(item.tmdbID)-\(item.mediaTypeRaw)"] = (item.userRating, item.watchedAt) }

        let filtered = filter.isEmpty
            ? entries
            : entries.filter { $0.title.localizedCaseInsensitiveContains(filter) }

        // The Watch List represents a show by its tracked (next-incomplete) season, keyed by
        // show id. Last write wins if sync momentarily duplicates. Empty for custom lists.
        var trackedByShow: [Int: TrackedSeason] = [:]
        if isWatchList {
            for tracked in (try? modelContext.fetch(FetchDescriptor<TrackedSeason>())) ?? [] {
                trackedByShow[tracked.showTmdbID] = tracked
            }
        }
        let watchedBySeason = watchedEpisodeCounts()

        let dated = filtered.map { entry -> (date: Date, snapshot: MediaSnapshot) in
            let facts = factsByKey["\(entry.tmdbID)-\(entry.mediaTypeRaw)"]
            if entry.mediaType == .tv, let tracked = trackedByShow[entry.tmdbID] {
                let watched = watchedBySeason["\(entry.tmdbID)-\(tracked.seasonNumber)"] ?? 0
                // The tracked season buckets by its next unwatched episode's air date.
                let date = byDateAdded ? entry.addedAt
                    : (tracked.nextEpisodeDate ?? entry.sortDate ?? entry.releaseDate ?? .distantFuture)
                return (date,
                        MediaSnapshot(persistentID: entry.persistentModelID,
                                      tmdbID: entry.tmdbID, mediaType: .tv,
                                      title: tracked.showName.isEmpty ? entry.title : tracked.showName,
                                      posterPath: tracked.posterPath ?? entry.posterPath,
                                      releaseDate: entry.releaseDate,
                                      sortDate: tracked.nextEpisodeDate ?? entry.sortDate,
                                      seasonNumber: tracked.seasonNumber,
                                      seasonWatched: watched, seasonTotal: tracked.episodeCount,
                                      runtime: entry.runtime,
                                      dateWatched: facts?.watched, userRating: facts?.rating))
            }
            // Movies, and untracked shows (no progress / fully watched), keep the whole-title snapshot.
            let date = byDateAdded ? entry.addedAt : (entry.sortDate ?? entry.releaseDate ?? .distantFuture)
            return (date,
                    MediaSnapshot(persistentID: entry.persistentModelID,
                                  tmdbID: entry.tmdbID, mediaType: entry.mediaType, title: entry.title,
                                  posterPath: entry.posterPath, releaseDate: entry.releaseDate,
                                  sortDate: entry.sortDate, seasonNumber: nil,
                                  seasonWatched: nil, seasonTotal: nil, runtime: entry.runtime,
                                  dateWatched: facts?.watched, userRating: facts?.rating))
        }
        if byDateAdded { return flat(dated, ascending: ascending) }
        // Only the Watch List folds stale titles into an "Older" bucket, and only
        // when the user leaves the toggle on; custom lists keep every month live.
        let cutoff = (isWatchList && foldOlder) ? olderCutoff() : nil
        return group(dated, ascending: ascending, foldOlderThan: cutoff)
    }

    // MARK: Derived Watched (MediaItem, grouped by month)

    private func buildWatched(sort: WatchedSortKey, ascending: Bool, filter: String) -> [SectionSnapshot] {
        let byWatchedDate = sort == .dateWatched
        var dated: [(date: Date, snapshot: MediaSnapshot)] = []

        // Movies track watched at the item level; TV tracks at the season level, so pull
        // only movie MediaItems here and add watched seasons below.
        let movieType = MediaType.movie.rawValue
        let itemDescriptor = FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.watchedAt != nil && $0.mediaTypeRaw == movieType })
        for item in (try? modelContext.fetch(itemDescriptor)) ?? []
        where filter.isEmpty || item.title.localizedCaseInsensitiveContains(filter) {
            let anchor = item.sortDate ?? item.releaseDate ?? .distantFuture
            let date = byWatchedDate ? (item.watchedAt ?? .distantFuture) : anchor
            dated.append((date, snapshot(from: item)))
        }

        // Watched counts derive from the episode source of truth, keyed by show+season.
        let watchedBySeason = watchedEpisodeCounts()

        for season in (try? modelContext.fetch(FetchDescriptor<WatchedSeason>())) ?? []
        where filter.isEmpty || season.showName.localizedCaseInsensitiveContains(filter) {
            let anchor = season.airDate ?? season.watchedAt
            let date = byWatchedDate ? season.watchedAt : anchor
            let watched = watchedBySeason["\(season.showTmdbID)-\(season.seasonNumber)"] ?? 0
            dated.append((date, snapshot(from: season, watched: watched)))
        }

        // Rating sort groups by star count instead of month; unrated titles (including
        // watched seasons, which carry no rating) fall into their own bucket.
        if sort == .rating { return groupByRating(dated, ascending: ascending) }
        return group(dated, ascending: ascending)
    }

    /// Buckets rows by half-star steps (0…10). Each distinct rating is one section,
    /// ordered by stars; within a bucket the newest anchor date leads.
    private func groupByRating(_ dated: [(date: Date, snapshot: MediaSnapshot)],
                               ascending: Bool) -> [SectionSnapshot] {
        var buckets: [Int: [(date: Date, snapshot: MediaSnapshot)]] = [:]
        for item in dated {
            let rating = item.snapshot.userRating ?? 0
            let steps = rating > 0 ? Int((rating * 2).rounded()) : 0
            buckets[steps, default: []].append(item)
        }
        let keys = buckets.keys.sorted()
        let ordered = ascending ? keys : keys.reversed().map { $0 }
        return ordered.map { steps in
            let entries = buckets[steps]!.sorted { $0.date > $1.date }.map(\.snapshot)
            // Rating-derived section id; the +9000 offset can't collide with month keys.
            // Rated sections carry a star value for the header; "Unrated" (0) shows text.
            return SectionSnapshot(id: DateComponents(year: 9000 + steps),
                                   title: ratingTitle(steps), entries: entries, isCollapsible: false,
                                   ratingStars: steps > 0 ? Double(steps) / 2 : nil)
        }
    }

    private func ratingTitle(_ halfSteps: Int) -> String {
        guard halfSteps > 0 else { return "Unrated" }
        let stars = Double(halfSteps) / 2
        let text = stars == stars.rounded() ? String(format: "%.0f", stars) : String(format: "%.1f", stars)
        return "\(text) \(halfSteps == 2 ? "Star" : "Stars")"
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

    /// Watched-episode counts keyed `"showID-season"`, derived from the `WatchedEpisode`
    /// source of truth. Shared by the Watched rows and the tracked-season membership rows.
    private func watchedEpisodeCounts() -> [String: Int] {
        var map: [String: Int] = [:]
        for episode in (try? modelContext.fetch(FetchDescriptor<WatchedEpisode>())) ?? [] {
            map["\(episode.showTmdbID)-\(episode.seasonNumber)", default: 0] += 1
        }
        return map
    }

    private func snapshot(from item: MediaItem) -> MediaSnapshot {
        MediaSnapshot(persistentID: item.persistentModelID, tmdbID: item.tmdbID,
                      mediaType: item.mediaType, title: item.title,
                      posterPath: item.posterPath, releaseDate: item.releaseDate,
                      sortDate: item.sortDate, seasonNumber: nil,
                      seasonWatched: nil, seasonTotal: nil, runtime: item.runtime,
                      dateWatched: item.watchedAt, userRating: item.userRating)
    }

    private func snapshot(from season: WatchedSeason, watched: Int) -> MediaSnapshot {
        MediaSnapshot(persistentID: season.persistentModelID, tmdbID: season.showTmdbID,
                      mediaType: .tv, title: season.showName,
                      posterPath: season.posterPath, releaseDate: season.airDate,
                      sortDate: season.airDate, seasonNumber: season.seasonNumber,
                      seasonWatched: watched, seasonTotal: season.episodeCount,
                      runtime: nil, dateWatched: season.watchedAt, userRating: season.userRating)
    }

    // MARK: Grouping

    private func flat(_ dated: [(date: Date, snapshot: MediaSnapshot)],
                      ascending: Bool) -> [SectionSnapshot] {
        let sorted = dated.sorted { $0.date < $1.date }
        let ordered = ascending ? sorted : Array(sorted.reversed())
        let snapshots = ordered.map(\.snapshot)
        return snapshots.isEmpty ? [] : [SectionSnapshot(id: DateComponents(), title: "", entries: snapshots, isCollapsible: false)]
    }

    /// Fold thresholds. Only tuck old titles into the collapsed "Older" bucket when
    /// there's a meaningful block of recent/upcoming releases worth keeping on screen
    /// (>= `foldMinRecent`) and a backlog large enough to be worth hiding
    /// (>= `foldMinOlder`). Below either, an "Older" bucket would hide more than it
    /// helps, so the list stays fully expanded.
    private static let foldMinRecent = 2
    private static let foldMinOlder = 3

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
            let recentSplit = dated.filter { $0.date >= cutoff }
            let olderSplit = dated.filter { $0.date < cutoff }
            // Fold only when there's a real new-releases block to protect and a backlog
            // worth hiding; otherwise (e.g. an all-old list, or just a couple of each)
            // an "Older" bucket would bury content instead of surfacing what's next.
            if recentSplit.count >= Self.foldMinRecent && olderSplit.count >= Self.foldMinOlder {
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

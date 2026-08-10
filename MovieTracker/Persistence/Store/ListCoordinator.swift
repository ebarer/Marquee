//
//  ListCoordinator.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// Loads a list's rows on a background context: fetches the source `@Model`s, resolves each
/// row's section-anchor date, and picks the `SectionLayout`. Arranging rows into titled, sorted
/// sections is `SectionFormatter`'s job (presentation). Distinct from `PersistenceCoordinator`,
/// the main-actor writer — this is the off-main reader the Lists screen awaits.
@ModelActor
actor ListCoordinator {
    func load(request: ListRequest, filter: String, mediaFilter: MediaTypeFilter = .all) -> ListResult {
        let result: ListResult
        switch request {
        case .list(let listID, let byDateAdded, let foldOlder):
            result = loadList(listID, byDateAdded: byDateAdded, foldOlder: foldOlder, filter: filter)
        case .watched(let sort):
            result = loadWatched(sort: sort, filter: filter)
        case .viewed:
            result = loadViewed(filter: filter)
        }
        return applyMediaFilter(result, mediaFilter)
    }

    /// Drop rows that don't match the media-type filter, so empty sections never form.
    private func applyMediaFilter(_ result: ListResult, _ mediaFilter: MediaTypeFilter) -> ListResult {
        guard mediaFilter != .all else { return result }
        return ListResult(rows: result.rows.filter { mediaFilter.matches($0.snapshot.mediaType) },
                          layout: result.layout)
    }

    // MARK: List membership (ListEntry)

    private func loadList(_ listID: UUID, byDateAdded: Bool, foldOlder: Bool, filter: String) -> ListResult {
        // Only the Watch List folds a stale backlog into "Older", and only under release-date
        // sort; by-date-added is a flat list.
        let layout: SectionLayout = byDateAdded ? .flat : .months(foldOlder: false)

        let descriptor = FetchDescriptor<ListEntry>(predicate: #Predicate { $0.list?.uuid == listID })
        guard let entries = try? modelContext.fetch(descriptor) else {
            return ListResult(rows: [], layout: layout)
        }

        // Only the Watch List represents a show by its tracked season; custom lists show the
        // whole show (seasons belong to the Watch List / Watched).
        let isWatchList = entries.first?.list?.isWatchList ?? false

        let items = (try? modelContext.fetch(FetchDescriptor<MediaItem>())) ?? []
        // Key facts by (tmdbID, mediaType) so a movie and show sharing a tmdbID don't collide.
        var factsByKey: [String: (rating: Double?, watched: Date?)] = [:]
        for item in items { factsByKey["\(item.tmdbID)-\(item.mediaTypeRaw)"] = (item.userRating, item.watchedAt) }

        let filtered = filter.isEmpty ? entries
            : entries.filter { $0.title.localizedCaseInsensitiveContains(filter) }

        // The Watch List represents a show by its tracked (next-incomplete) season, keyed by
        // show id. Empty for custom lists.
        var trackedByShow: [Int: TrackedSeason] = [:]
        if isWatchList {
            for tracked in (try? modelContext.fetch(FetchDescriptor<TrackedSeason>())) ?? [] {
                trackedByShow[tracked.showTmdbID] = tracked
            }
        }
        let watchedBySeason = watchedEpisodeCounts()

        let rows = filtered.map { entry -> DatedRow in
            let facts = factsByKey["\(entry.tmdbID)-\(entry.mediaTypeRaw)"]
            if entry.mediaType == .tv, let tracked = trackedByShow[entry.tmdbID] {
                let watched = watchedBySeason["\(entry.tmdbID)-\(tracked.seasonNumber)"] ?? 0
                // The tracked season buckets by its next unwatched episode's air date.
                let date = byDateAdded ? entry.addedAt
                    : (tracked.nextEpisodeDate ?? entry.sortDate ?? entry.releaseDate ?? .distantFuture)
                return DatedRow(date: date,
                                snapshot: MediaSnapshot(persistentID: entry.persistentModelID,
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
            return DatedRow(date: date,
                            snapshot: MediaSnapshot(persistentID: entry.persistentModelID,
                                                    tmdbID: entry.tmdbID, mediaType: entry.mediaType, title: entry.title,
                                                    posterPath: entry.posterPath, releaseDate: entry.releaseDate,
                                                    sortDate: entry.sortDate, seasonNumber: nil,
                                                    seasonWatched: nil, seasonTotal: nil, runtime: entry.runtime,
                                                    dateWatched: facts?.watched, userRating: facts?.rating))
        }
        return ListResult(rows: rows, layout: byDateAdded ? .flat : .months(foldOlder: isWatchList && foldOlder))
    }

    // MARK: Derived Watched (MediaItem + WatchedSeason)

    private func loadWatched(sort: WatchedSortKey, filter: String) -> ListResult {
        let byWatchedDate = sort == .dateWatched
        var rows: [DatedRow] = []

        // Movies track watched at the item level; TV at the season level, so pull only movie
        // MediaItems here and add watched seasons below.
        let movieType = MediaType.movie.rawValue
        let itemDescriptor = FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.watchedAt != nil && $0.mediaTypeRaw == movieType })
        for item in (try? modelContext.fetch(itemDescriptor)) ?? []
        where filter.isEmpty || item.title.localizedCaseInsensitiveContains(filter) {
            let anchor = item.sortDate ?? item.releaseDate ?? .distantFuture
            let date = byWatchedDate ? (item.watchedAt ?? .distantFuture) : anchor
            rows.append(DatedRow(date: date, snapshot: snapshot(from: item)))
        }

        // Watched counts derive from the episode source of truth, keyed by show+season.
        let watchedBySeason = watchedEpisodeCounts()
        for season in (try? modelContext.fetch(FetchDescriptor<WatchedSeason>())) ?? []
        where filter.isEmpty || season.showName.localizedCaseInsensitiveContains(filter) {
            let anchor = season.airDate ?? season.watchedAt
            let date = byWatchedDate ? season.watchedAt : anchor
            let watched = watchedBySeason["\(season.showTmdbID)-\(season.seasonNumber)"] ?? 0
            rows.append(DatedRow(date: date, snapshot: snapshot(from: season, watched: watched)))
        }

        // Rating sort buckets by star count; every other sort groups by month.
        return ListResult(rows: rows, layout: sort == .rating ? .ratingStars : .months(foldOlder: false))
    }

    // MARK: Derived Viewed (MediaItem, flat recency)

    private func loadViewed(filter: String) -> ListResult {
        let descriptor = FetchDescriptor<MediaItem>(predicate: #Predicate { $0.lastViewedAt != nil })
        guard let items = try? modelContext.fetch(descriptor) else {
            return ListResult(rows: [], layout: .flat)
        }
        let filtered = filter.isEmpty ? items
            : items.filter { $0.title.localizedCaseInsensitiveContains(filter) }
        let rows = filtered.map { DatedRow(date: $0.lastViewedAt ?? .distantPast, snapshot: snapshot(from: $0)) }
        return ListResult(rows: rows, layout: .flat)
    }

    // MARK: Row helpers

    /// Watched-episode counts keyed `"showID-season"`, from the `WatchedEpisode` source of truth.
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
}

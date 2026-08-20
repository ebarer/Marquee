//
//  ListCoordinator.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// Off-main reader for the Lists screen. Not a `@ModelActor`: that ran on main for main-actor callers.
final class ListCoordinator {
    let modelContext: ModelContext

    init(container: ModelContainer) {
        modelContext = ModelContext(container)
    }

    func runsOnMainThread() -> Bool { Thread.isMainThread }

    // Scans every watched title, Watch List entry and watched episode: far more than a frame's worth.
    func badgeIndex() -> MediaBadgeIndex {
        MediaBadgeIndex(context: modelContext)
    }

    // Formatting sorts every row and runs a `DateFormatter` per section, so it stays off the main actor.
    func sections(request: ListRequest, ascending: Bool, filter: String,
                  mediaFilter: MediaTypeFilter = .all) -> [SectionSnapshot] {
        SectionFormatter.sections(from: load(request: request, filter: filter,
                                             mediaFilter: mediaFilter),
                                  ascending: ascending)
    }

    func load(request: ListRequest, filter: String, mediaFilter: MediaTypeFilter = .all) -> ListResult {
        let result: ListResult
        switch request {
        case .list(let listID, let sort, let foldOlder):
            result = loadList(listID, sort: sort, foldOlder: foldOlder, filter: filter)
        case .watched(let sort):
            result = loadWatched(sort: sort, filter: filter)
        case .viewed:
            result = loadViewed(filter: filter)
        }
        return applyMediaFilter(result, mediaFilter)
    }

    private func applyMediaFilter(_ result: ListResult, _ mediaFilter: MediaTypeFilter) -> ListResult {
        guard mediaFilter != .all else { return result }
        return ListResult(rows: result.rows.filter { mediaFilter.matches($0.snapshot.mediaType) },
                          layout: result.layout)
    }

    // MARK: List membership (ListEntry)

    private func loadList(_ listID: UUID, sort: ListSortKey, foldOlder: OlderFold, filter: String) -> ListResult {
        // Only the Watch List folds a stale backlog into "Older", and only under release-date sort.
        func layout(isWatchList: Bool) -> SectionLayout {
            switch sort {
            case .dateAdded: return .flat
            case .rating: return .ratingStars
            case .alphabetical: return .initials
            case .releaseDate: return .months(foldOlder: isWatchList ? foldOlder : [])
            }
        }
        let byDateAdded = sort == .dateAdded

        let descriptor = FetchDescriptor<ListEntry>(predicate: #Predicate { $0.list?.uuid == listID })
        guard let entries = try? modelContext.fetch(descriptor) else {
            return ListResult(rows: [], layout: layout(isWatchList: false))
        }

        // Only the Watch List represents a show by its tracked season; custom lists show the whole show.
        let isWatchList = entries.first?.list?.isWatchList ?? false

        let items = (try? modelContext.fetch(FetchDescriptor<MediaItem>())) ?? []
        // Key facts by (tmdbID, mediaType) so a movie and show sharing a tmdbID don't collide.
        var factsByKey: [String: (rating: Double?, watched: Date?)] = [:]
        for item in items { factsByKey["\(item.tmdbID)-\(item.mediaTypeRaw)"] = (item.userRating, item.watchedAt) }

        let filtered = filter.isEmpty ? entries
            : entries.filter { $0.title.localizedCaseInsensitiveContains(filter) }

        // The Watch List represents a show by its next-incomplete season, keyed by show id. Empty elsewhere.
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
                                                        nextEpisodeDate: tracked.nextEpisodeDate,
                                                        runtime: entry.runtime,
                                                        dateWatched: facts?.watched, userRating: facts?.rating))
            }
            let date = byDateAdded ? entry.addedAt : (entry.sortDate ?? entry.releaseDate ?? .distantFuture)
            return DatedRow(date: date,
                            snapshot: MediaSnapshot(persistentID: entry.persistentModelID,
                                                    tmdbID: entry.tmdbID, mediaType: entry.mediaType, title: entry.title,
                                                    posterPath: entry.posterPath, releaseDate: entry.releaseDate,
                                                    sortDate: entry.sortDate, seasonNumber: nil,
                                                    seasonWatched: nil, seasonTotal: nil,
                                                    nextEpisodeDate: nil, runtime: entry.runtime,
                                                    dateWatched: facts?.watched, userRating: facts?.rating))
        }
        return ListResult(rows: rows, layout: layout(isWatchList: isWatchList))
    }

    // MARK: Derived Watched (MediaItem + WatchedSeason)

    private func loadWatched(sort: WatchedSortKey, filter: String) -> ListResult {
        let byWatchedDate = sort == .dateWatched
        var rows: [DatedRow] = []

        // Movies track watched at the item level and TV at the season level, so pull only movie items here.
        let movieType = MediaType.movie.rawValue
        let itemDescriptor = FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.watchedAt != nil && $0.mediaTypeRaw == movieType })
        for item in (try? modelContext.fetch(itemDescriptor)) ?? []
        where filter.isEmpty || item.title.localizedCaseInsensitiveContains(filter) {
            let anchor = item.sortDate ?? item.releaseDate ?? .distantFuture
            let date = byWatchedDate ? (item.watchedAt ?? .distantFuture) : anchor
            rows.append(DatedRow(date: date, snapshot: snapshot(from: item)))
        }

        let watchedBySeason = watchedEpisodeCounts()
        for season in (try? modelContext.fetch(FetchDescriptor<WatchedSeason>())) ?? []
        where filter.isEmpty || season.showName.localizedCaseInsensitiveContains(filter) {
            let anchor = season.airDate ?? season.watchedAt
            let date = byWatchedDate ? season.watchedAt : anchor
            let watched = watchedBySeason["\(season.showTmdbID)-\(season.seasonNumber)"] ?? 0
            rows.append(DatedRow(date: date, snapshot: snapshot(from: season, watched: watched)))
        }

        let layout: SectionLayout
        switch sort {
        case .rating: layout = .ratingStars
        case .alphabetical: layout = .initials
        case .dateWatched, .releaseDate: layout = .months(foldOlder: [])
        }
        return ListResult(rows: rows, layout: layout)
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
                      seasonWatched: nil, seasonTotal: nil,
                      nextEpisodeDate: nil, runtime: item.runtime,
                      dateWatched: item.watchedAt, userRating: item.userRating)
    }

    private func snapshot(from season: WatchedSeason, watched: Int) -> MediaSnapshot {
        MediaSnapshot(persistentID: season.persistentModelID, tmdbID: season.showTmdbID,
                      mediaType: .tv, title: season.showName,
                      posterPath: season.posterPath, releaseDate: season.airDate,
                      sortDate: season.airDate, seasonNumber: season.seasonNumber,
                      seasonWatched: watched, seasonTotal: season.episodeCount,
                      nextEpisodeDate: nil, runtime: nil,
                      dateWatched: season.watchedAt, userRating: season.userRating)
    }
}

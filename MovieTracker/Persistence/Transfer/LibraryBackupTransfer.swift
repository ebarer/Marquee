//
//  LibraryBackupTransfer.swift
//  MovieTracker
//

import Foundation
import SwiftData

// MARK: - Store: export / import

extension LibraryBackup {
    /// Stable on-disk values, independent of the runtime model so backups keep importing.
    enum Kind: Int {
        case custom = 0
        case toWatch = 1
        case watched = 2
        case viewed = 3
    }

    /// Watched is emitted as a v1 pseudo-list carrying dates/ratings, so old backups still import.
    static func export(from context: ModelContext) -> LibraryBackup {
        var lists = MediaList.all(in: context).map { list in
            LibraryBackup.List(
                uuid: list.uuid, name: list.name, symbol: list.symbol,
                colorIndex: list.colorIndex,
                kind: list.isWatchList ? Kind.toWatch.rawValue : Kind.custom.rawValue,
                sortOrder: list.sortOrder, createdAt: list.createdAt,
                entries: (list.entries ?? []).map { entry in
                    LibraryBackup.Entry(
                        movieID: entry.tmdbID, mediaType: entry.mediaTypeRaw, title: entry.title,
                        posterPath: entry.posterPath, releaseDate: entry.releaseDate,
                        sortDate: entry.sortDate, dateAdded: entry.addedAt,
                        dateWatched: nil, userRating: nil)
                }
            )
        }

        let watched = (try? context.fetch(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.watchedAt != nil }))) ?? []
        if !watched.isEmpty {
            lists.append(LibraryBackup.List(
                uuid: UUID(), name: "Watched", symbol: "checkmark.rectangle.stack",
                colorIndex: 0, kind: Kind.watched.rawValue, sortOrder: 2, createdAt: Date(),
                entries: watched.map { item in
                    LibraryBackup.Entry(
                        movieID: item.tmdbID, mediaType: item.mediaTypeRaw, title: item.title,
                        posterPath: item.posterPath, releaseDate: item.releaseDate,
                        sortDate: item.sortDate, dateAdded: item.addedAt,
                        dateWatched: item.watchedAt, userRating: item.userRating)
                }))
        }
        return LibraryBackup(lists: lists, shows: progress(in: context))
    }

    /// TV progress lives in models of its own, so it exports separately from list membership;
    /// without it every imported show reads as zero episodes watched.
    private static func progress(in context: ModelContext) -> [LibraryBackup.Progress] {
        let episodes = (try? context.fetch(FetchDescriptor<WatchedEpisode>())) ?? []
        let seasons = (try? context.fetch(FetchDescriptor<WatchedSeason>())) ?? []
        let tracked = TrackedSeason.all(in: context)
        let tvRaw = MediaType.tv.rawValue
        let flagged = ((try? context.fetch(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.mediaTypeRaw == tvRaw }))) ?? [])
            .filter { $0.showWatched == true || $0.showCaughtUp == true || $0.watchListOptOut == true }

        let episodesByShow = Dictionary(grouping: episodes, by: \.showTmdbID)
        let seasonsByShow = Dictionary(grouping: seasons, by: \.showTmdbID)
        let trackedByShow = Dictionary(tracked.map { ($0.showTmdbID, $0) }, uniquingKeysWith: { first, _ in first })
        let itemsByShow = Dictionary(flagged.map { ($0.tmdbID, $0) }, uniquingKeysWith: { first, _ in first })

        var ids = Set(episodesByShow.keys)
        ids.formUnion(seasonsByShow.keys)
        ids.formUnion(trackedByShow.keys)
        ids.formUnion(itemsByShow.keys)

        return ids.sorted().map { id in
            let item = itemsByShow[id]
            let snapshots = seasonsByShow[id] ?? []
            let anchor = trackedByShow[id]
            return LibraryBackup.Progress(
                tmdbID: id,
                name: item?.title ?? anchor?.showName ?? snapshots.first?.showName ?? "",
                posterPath: item?.posterPath ?? anchor?.posterPath ?? snapshots.first?.posterPath,
                isWatched: item?.showWatched,
                isCaughtUp: item?.showCaughtUp,
                watchListOptOut: item?.watchListOptOut,
                tracked: anchor.map {
                    .init(season: $0.seasonNumber, posterPath: $0.posterPath,
                          episodeCount: $0.episodeCount, nextEpisodeDate: $0.nextEpisodeDate)
                },
                seasons: snapshots.sorted { $0.seasonNumber < $1.seasonNumber }.map {
                    .init(season: $0.seasonNumber, name: $0.seasonName, posterPath: $0.posterPath,
                          airDate: $0.airDate, episodeCount: $0.episodeCount,
                          watchedAt: $0.watchedAt, userRating: $0.userRating)
                },
                episodes: (episodesByShow[id] ?? [])
                    .sorted { ($0.seasonNumber, $0.episodeNumber) < ($1.seasonNumber, $1.episodeNumber) }
                    .map { .init(season: $0.seasonNumber, episode: $0.episodeNumber, watchedAt: $0.watchedAt) }
            )
        }
    }

    /// Merges an archive additively; nothing existing is modified.
    @MainActor
    @discardableResult
    static func merge(_ archive: LibraryBackup, using store: PersistenceCoordinator) -> ImportSummary {
        var summary = ImportSummary()
        let context = store.context

        for archivedList in archive.lists {
            switch Kind(rawValue: archivedList.kind) ?? .custom {
            case .viewed:
                continue
            case .watched:
                for entry in archivedList.entries {
                    let item = MediaItem.upsert(key: key(from: entry), in: context)
                    if item.watchedAt == nil {
                        item.watchedAt = entry.dateWatched ?? MediaItem.floatingDay(from: Date())
                    }
                    if item.userRating == nil { item.userRating = entry.userRating }
                    summary.entriesAdded += 1
                }
            case .toWatch, .custom:
                let isWatchList = Kind(rawValue: archivedList.kind) == .toWatch
                guard let list = target(archivedList, isWatchList: isWatchList,
                                        using: store, summary: &summary) else { continue }
                for entry in archivedList.entries {
                    let key = key(from: entry)
                    guard !list.contains(key.tmdbID, key.mediaType) else {
                        summary.entriesSkipped += 1
                        continue
                    }
                    let member = ListEntry(key: key)
                    member.list = list
                    context.insert(member)
                    summary.entriesAdded += 1
                }
            }
        }
        mergeProgress(archive.shows, using: store)
        store.save()
        return summary
    }

    /// Restore TV progress additively: a record already present wins, so a re-import is a no-op
    /// and never re-dates an episode or season the user has since edited.
    @MainActor
    private static func mergeProgress(_ shows: [LibraryBackup.Progress],
                                      using store: PersistenceCoordinator) {
        let context = store.context
        for show in shows {
            for episode in show.episodes
            where WatchedEpisode.find(showTmdbID: show.tmdbID, seasonNumber: episode.season,
                                      episodeNumber: episode.episode, in: context) == nil {
                context.insert(WatchedEpisode(showTmdbID: show.tmdbID, seasonNumber: episode.season,
                                              episodeNumber: episode.episode,
                                              watchedAt: episode.watchedAt))
            }

            for season in show.seasons
            where WatchedSeason.find(showTmdbID: show.tmdbID, seasonNumber: season.season,
                                     in: context) == nil {
                let snapshot = WatchedSeason(
                    showTmdbID: show.tmdbID, seasonNumber: season.season, showName: show.name,
                    seasonName: season.name, posterPath: season.posterPath ?? show.posterPath,
                    airDate: season.airDate, episodeCount: season.episodeCount,
                    watchedAt: season.watchedAt)
                snapshot.userRating = season.userRating
                context.insert(snapshot)
            }

            if let tracked = show.tracked,
               TrackedSeason.find(showTmdbID: show.tmdbID, in: context) == nil {
                context.insert(TrackedSeason(
                    showTmdbID: show.tmdbID, seasonNumber: tracked.season, showName: show.name,
                    posterPath: tracked.posterPath ?? show.posterPath,
                    episodeCount: tracked.episodeCount, nextEpisodeDate: tracked.nextEpisodeDate))
            }

            applyShowFlags(show, in: context)
        }
    }

    /// The cached show-level flags, so badges read right before the show is next reconciled.
    private static func applyShowFlags(_ show: LibraryBackup.Progress, in context: ModelContext) {
        guard show.isWatched == true || show.isCaughtUp == true || show.watchListOptOut == true
        else { return }
        // Not `upsert`: the archive carries no release date or runtime, and a snapshot refresh
        // would clear whichever of those a list entry's import already established.
        let item: MediaItem
        if let existing = MediaItem.find(tmdbID: show.tmdbID, mediaType: .tv, in: context) {
            item = existing
        } else {
            item = MediaItem(tmdbID: show.tmdbID, mediaType: .tv, title: show.name)
            item.posterPath = show.posterPath
            context.insert(item)
        }
        item.showWatched = item.showWatched ?? show.isWatched
        item.showCaughtUp = item.showCaughtUp ?? show.isCaughtUp
        item.watchListOptOut = item.watchListOptOut ?? show.watchListOptOut
    }

    @MainActor
    private static func target(_ archived: LibraryBackup.List, isWatchList: Bool,
                               using store: PersistenceCoordinator, summary: inout ImportSummary) -> MediaList? {
        if isWatchList { return store.watchList }
        if let existing = MediaList.all(in: store.context).first(where: { $0.uuid == archived.uuid }) {
            return existing
        }
        let created = MediaList(name: archived.name, symbol: archived.symbol,
                                sortOrder: archived.sortOrder, colorIndex: archived.colorIndex)
        created.uuid = archived.uuid
        created.createdAt = archived.createdAt
        store.context.insert(created)
        summary.listsCreated += 1
        return created
    }

    private static func key(from entry: LibraryBackup.Entry) -> MediaKey {
        MediaKey(tmdbID: entry.movieID,
                 mediaType: MediaType(rawValue: entry.mediaType) ?? .movie,
                 title: entry.title, posterPath: entry.posterPath,
                 releaseDate: entry.releaseDate, runtime: nil, sortDate: entry.sortDate)
    }
}

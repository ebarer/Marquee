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
                        movieID: entry.tmdbID, title: entry.title, posterPath: entry.posterPath,
                        releaseDate: entry.releaseDate, dateAdded: entry.addedAt,
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
                        movieID: item.tmdbID, title: item.title, posterPath: item.posterPath,
                        releaseDate: item.releaseDate, dateAdded: item.addedAt,
                        dateWatched: item.watchedAt, userRating: item.userRating)
                }))
        }
        return LibraryBackup(lists: lists)
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
                    let item = MediaItem.upsert(movie(from: entry), in: context)
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
                    guard !list.contains(entry.movieID) else {
                        summary.entriesSkipped += 1
                        continue
                    }
                    let member = ListEntry(movie: movie(from: entry))
                    member.list = list
                    context.insert(member)
                    summary.entriesAdded += 1
                }
            }
        }
        store.save()
        return summary
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

    private static func movie(from entry: LibraryBackup.Entry) -> Movie {
        var movie = Movie(id: entry.movieID, title: entry.title)
        movie.poster = entry.posterPath
        movie.releaseDate = entry.releaseDate
        return movie
    }
}

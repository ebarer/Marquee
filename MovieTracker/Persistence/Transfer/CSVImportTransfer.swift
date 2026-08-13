//
//  CSVImportTransfer.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// `Sendable` (unlike `Movie`) so it can cross the task-group boundary.
private struct FetchedMeta: Sendable {
    let movieID: Int
    let posterPath: String?
    let releaseDate: Date?
}

extension CSVMovieRecord {
    @MainActor
    static func merge(_ records: [CSVMovieRecord],
                      using store: PersistenceCoordinator,
                      progress: (Int, Int) -> Void) async -> ImportSummary {
        var summary = ImportSummary()
        let context = store.context
        let watchList = store.watchList

        var pending: [CSVMovieRecord] = []
        for record in records {
            let present = record.watched
                ? (MediaItem.find(tmdbID: record.movieID, in: context)?.isWatched ?? false)
                : watchList.contains(record.movieID)
            if present { summary.entriesSkipped += 1 } else { pending.append(record) }
        }

        let total = pending.count
        progress(0, total)
        guard total > 0 else { return summary }

        // Bounded concurrency so we don't flood TMDB.
        var metaByID: [Int: FetchedMeta] = [:]
        var completed = 0
        let maxConcurrent = 8

        await withTaskGroup(of: FetchedMeta.self) { group in
            var iterator = pending.makeIterator()
            for _ in 0..<maxConcurrent {
                guard let record = iterator.next() else { break }
                group.addTask { await fetchMeta(for: record) }
            }
            for await meta in group {
                metaByID[meta.movieID] = meta
                completed += 1
                progress(completed, total)
                if let record = iterator.next() {
                    group.addTask { await fetchMeta(for: record) }
                }
            }
        }

        for record in pending {
            let meta = metaByID[record.movieID]
            let releaseDate = meta?.releaseDate ?? record.releaseDate
            var movie = Movie(id: record.movieID, title: record.title)
            movie.poster = meta?.posterPath
            movie.releaseDate = releaseDate

            if record.watched {
                let item = MediaItem.upsert(movie, in: context)
                // The CSV has no watched date; stand in with the release date so
                // watched titles group sensibly.
                item.watchedAt = releaseDate.map(MediaItem.floatingDay) ?? MediaItem.floatingDay(from: Date())
                item.userRating = record.userRating
            } else {
                watchList.add(movie)
            }
            summary.entriesAdded += 1
        }
        store.save()
        return summary
    }

    private static func fetchMeta(for record: CSVMovieRecord) async -> FetchedMeta {
        if let movie = try? await TMDBWrapper.getMovie(id: record.movieID) {
            return FetchedMeta(movieID: record.movieID,
                               posterPath: movie.poster,
                               releaseDate: movie.releaseDate ?? record.releaseDate)
        }
        return FetchedMeta(movieID: record.movieID,
                           posterPath: nil,
                           releaseDate: record.releaseDate)
    }
}

//
//  CSVImport.swift
//  MovieTracker
//
//  Imports a TodoMovies CSV export, fetching each row's details from TMDB by id.
//

import Foundation
import SwiftData

/// One importable movie parsed from a CSV row.
struct CSVMovieRecord {
    var movieID: Int
    var title: String
    var releaseDate: Date?
    var watched: Bool
    var userRating: Double?
}

// MARK: - Parsing

enum CSVImportError: LocalizedError {
    case emptyFile
    case missingColumns

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The CSV file is empty."
        case .missingColumns:
            return "This CSV doesn't look like a TodoMovies export (missing a TMDB ID column)."
        }
    }
}

extension CSVMovieRecord {
    static func parse(data: Data) throws -> [CSVMovieRecord] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CSVImportError.emptyFile
        }

        let rows = CSVParser.rows(from: text)
        guard let header = rows.first else { throw CSVImportError.emptyFile }

        var indexByName: [String: Int] = [:]
        for (index, name) in header.enumerated() {
            indexByName[name.trimmingCharacters(in: .whitespaces).lowercased()] = index
        }

        guard let idIndex = indexByName["tmdb id"] else {
            throw CSVImportError.missingColumns
        }
        let titleIndex = indexByName["title"]
        let releaseIndex = indexByName["release date"]
        let watchedIndex = indexByName["watched"]
        let ratingIndex = indexByName["your rating"]

        // TodoMovies writes release dates as e.g. "7/19/07".
        let releaseFormatter = DateFormatter()
        releaseFormatter.locale = Locale(identifier: "en_US_POSIX")
        releaseFormatter.dateFormat = "M/d/yy"

        func field(_ row: [String], _ index: Int?) -> String? {
            guard let index, index < row.count else { return nil }
            let value = row[index].trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }

        var records: [CSVMovieRecord] = []
        for row in rows.dropFirst() {
            guard let idString = field(row, idIndex), let movieID = Int(idString) else {
                continue
            }
            let record = CSVMovieRecord(
                movieID: movieID,
                title: field(row, titleIndex) ?? "",
                releaseDate: field(row, releaseIndex).flatMap { releaseFormatter.date(from: $0) },
                watched: field(row, watchedIndex) == "1",
                userRating: field(row, ratingIndex).flatMap(Double.init)
            )
            records.append(record)
        }
        return records
    }
}

/// A minimal RFC 4180 CSV reader: handles quoted fields, embedded commas and
/// newlines, and doubled quotes as an escaped quote.
private enum CSVParser {
    static func rows(from text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        var iterator = text.makeIterator()
        var pending: Character?

        func nextChar() -> Character? {
            if let c = pending { pending = nil; return c }
            return iterator.next()
        }

        func endField() { row.append(field); field = "" }
        func endRow() {
            endField()
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
            row = []
        }

        while let char = nextChar() {
            if inQuotes {
                if char == "\"" {
                    if let peek = nextChar() {
                        if peek == "\"" { field.append("\"") }
                        else { inQuotes = false; pending = peek }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else {
                switch char {
                case "\"": inQuotes = true
                case ",": endField()
                case "\n": endRow()
                case "\r":
                    // Swallow the \n of a CRLF pair.
                    if let peek = nextChar(), peek != "\n" { pending = peek }
                    endRow()
                default: field.append(char)
                }
            }
        }

        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }
}

// MARK: - Store: CSV import

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

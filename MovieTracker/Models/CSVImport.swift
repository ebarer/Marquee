//
//  CSVImport.swift
//  MovieTracker
//
//  Imports a TodoMovies CSV export, fetching each row's full movie details from
//  TMDB by its id while merging. Column layout:
//    Title, Genre, Release Date, Watched, Your Rating, TMDB URL, TMDB ID,
//    Watched Date, Comments
//

import Foundation
import SwiftData

/// One importable movie parsed from a CSV row. Only the fields the app can use
/// are kept; genre, TMDB URL, watched date, and comments are ignored (the export
/// leaves the latter two empty and the app has no field for them).
struct CSVMovieRecord {
    var movieID: Int
    var title: String
    /// Release date parsed from the CSV, used only as a fallback if the TMDB
    /// fetch fails.
    var releaseDate: Date?
    /// True when the row's "Watched" column is set (`1`).
    var watched: Bool
    /// Personal rating in stars (whole 1–5 in the export), `nil` when unrated.
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
    /// Parses a TodoMovies CSV export into records, skipping rows without a valid
    /// TMDB id. Column order is resolved from the header, so extra or reordered
    /// columns are tolerated.
    static func parse(data: Data) throws -> [CSVMovieRecord] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CSVImportError.emptyFile
        }

        let rows = CSVParser.rows(from: text)
        guard let header = rows.first else { throw CSVImportError.emptyFile }

        // Map header names (case-insensitive) to their column index.
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
            // Skip blank trailing lines.
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
            row = []
        }

        while let char = nextChar() {
            if inQuotes {
                if char == "\"" {
                    if let peek = nextChar() {
                        if peek == "\"" { field.append("\"") } // escaped quote
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

        // Flush any final field/row not terminated by a newline.
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }
}

// MARK: - Store: CSV import

/// Metadata fetched from TMDB for one movie during a CSV import. Kept `Sendable`
/// (unlike `Movie`) so it can cross the task-group boundary.
private struct FetchedMeta: Sendable {
    let movieID: Int
    let posterPath: String?
    let releaseDate: Date?
}

extension WatchListStore {
    /// Merges parsed CSV records into the library, fetching each movie's poster
    /// and release date from TMDB as it goes. Like the archive importer this is
    /// purely additive: a movie already on its target list is left untouched.
    /// `progress` is reported as `(fetched, total)` on the main actor.
    @MainActor
    static func importCSV(_ records: [CSVMovieRecord],
                          into context: ModelContext,
                          progress: (Int, Int) -> Void) async -> ImportSummary {
        var summary = ImportSummary()
        let (toWatch, watched) = ensureDefaultLists(in: context)

        func target(for record: CSVMovieRecord) -> MovieList {
            record.watched ? watched : toWatch
        }

        // Split into rows we'll insert vs. ones already present (skipped).
        var pending: [CSVMovieRecord] = []
        for record in records {
            if entry(for: record.movieID, in: target(for: record)) != nil {
                summary.entriesSkipped += 1
            } else {
                pending.append(record)
            }
        }

        let total = pending.count
        progress(0, total)
        guard total > 0 else { return summary }

        // Fetch details with bounded concurrency, keeping the network busy
        // without flooding TMDB. Results are collected by id.
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

        // Insert in the CSV's original order, preferring fetched metadata and
        // falling back to what the CSV provided.
        for record in pending {
            let meta = metaByID[record.movieID]
            let releaseDate = meta?.releaseDate ?? record.releaseDate
            let entry = WatchListEntry(movie: Movie(id: record.movieID, title: record.title))
            entry.posterPath = meta?.posterPath
            entry.releaseDate = releaseDate
            entry.userRating = record.userRating
            // The CSV has no watched date; stand in with the release date for
            // watched entries so they group sensibly (editable later in the app).
            if record.watched { entry.dateWatched = releaseDate }
            entry.list = target(for: record)
            context.insert(entry)
            summary.entriesAdded += 1
        }
        return summary
    }

    /// Fetches poster/release date for one record, falling back to the CSV's own
    /// release date if the network request fails.
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

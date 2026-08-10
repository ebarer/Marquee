//
//  CSVMovieRecord.swift
//  MovieTracker
//
//  Imports a TodoMovies CSV export, fetching each row's details from TMDB by id.
//

import Foundation

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

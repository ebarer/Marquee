//
//  LibraryBackup.swift
//  MovieTracker
//
//  A versioned backup snapshot, kept independent of the `@Model` types so the format stays stable.
//

import Foundation

struct LibraryBackup: Codable {
    static let currentVersion = 1

    var version = currentVersion
    var exportedAt = Date()
    var lists: [List]

    struct List: Codable {
        var uuid: UUID
        var name: String
        var symbol: String
        var colorIndex: Int
        var kind: Int
        var sortOrder: Int
        var createdAt: Date
        var entries: [Entry]
    }

    struct Entry: Codable {
        var movieID: Int
        var title: String
        var posterPath: String?
        var releaseDate: Date?
        var dateAdded: Date
        var dateWatched: Date?
        var userRating: Double?

        enum CodingKeys: String, CodingKey {
            case movieID, title, posterPath, releaseDate, dateAdded, dateWatched, userRating
        }

        init(movieID: Int, title: String, posterPath: String?, releaseDate: Date?,
             dateAdded: Date, dateWatched: Date?, userRating: Double?) {
            self.movieID = movieID
            self.title = title
            self.posterPath = posterPath
            self.releaseDate = releaseDate
            self.dateAdded = dateAdded
            self.dateWatched = dateWatched
            self.userRating = userRating
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            movieID = try c.decode(Int.self, forKey: .movieID)
            title = try c.decode(String.self, forKey: .title)
            posterPath = try c.decodeIfPresent(String.self, forKey: .posterPath)
            releaseDate = try c.decodeIfPresent(Date.self, forKey: .releaseDate)
            dateAdded = try c.decode(Date.self, forKey: .dateAdded)
            dateWatched = try c.decodeIfPresent(Date.self, forKey: .dateWatched)
            // Legacy files store rating as a whole Int; accept either.
            if let d = try? c.decode(Double.self, forKey: .userRating) {
                userRating = d
            } else if let i = try? c.decode(Int.self, forKey: .userRating) {
                userRating = Double(i)
            } else {
                userRating = nil
            }
        }
    }
}

// MARK: - JSON

extension LibraryBackup {
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func jsonData() throws -> Data { try Self.makeEncoder().encode(self) }

    init(json data: Data) throws {
        let decoded = try Self.makeDecoder().decode(LibraryBackup.self, from: data)
        guard decoded.version <= LibraryBackup.currentVersion else {
            throw ImportError.unsupportedVersion(decoded.version)
        }
        self = decoded
    }
}

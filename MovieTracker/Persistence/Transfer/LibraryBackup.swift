//
//  LibraryBackup.swift
//  MovieTracker
//
//  A versioned backup snapshot, kept independent of the `@Model` types so the format stays stable.
//

import Foundation

struct LibraryBackup: Codable {
    static let currentVersion = 2

    var version = currentVersion
    var exportedAt = Date()
    var lists: [List]
    var shows: [Progress]

    enum CodingKeys: String, CodingKey {
        case version, exportedAt, lists, shows
    }

    init(lists: [List], shows: [Progress] = []) {
        self.lists = lists
        self.shows = shows
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        lists = try container.decode([List].self, forKey: .lists)
        shows = try container.decodeIfPresent([Progress].self, forKey: .shows) ?? []
    }

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
        // Absent in files written before shows were tracked, so a missing key decodes as `.movie`.
        var mediaType: Int
        var title: String
        var posterPath: String?
        var releaseDate: Date?
        var sortDate: Date?
        var dateAdded: Date
        var dateWatched: Date?
        var userRating: Double?

        enum CodingKeys: String, CodingKey {
            case movieID, mediaType, title, posterPath, releaseDate, sortDate
            case dateAdded, dateWatched, userRating
        }

        init(movieID: Int, mediaType: Int = MediaType.movie.rawValue, title: String,
             posterPath: String?, releaseDate: Date?, sortDate: Date? = nil,
             dateAdded: Date, dateWatched: Date?, userRating: Double?) {
            self.movieID = movieID
            self.mediaType = mediaType
            self.title = title
            self.posterPath = posterPath
            self.releaseDate = releaseDate
            self.sortDate = sortDate
            self.dateAdded = dateAdded
            self.dateWatched = dateWatched
            self.userRating = userRating
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            movieID = try container.decode(Int.self, forKey: .movieID)
            mediaType = try container.decodeIfPresent(Int.self, forKey: .mediaType)
                ?? MediaType.movie.rawValue
            title = try container.decode(String.self, forKey: .title)
            posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
            releaseDate = try container.decodeIfPresent(Date.self, forKey: .releaseDate)
            sortDate = try container.decodeIfPresent(Date.self, forKey: .sortDate)
            dateAdded = try container.decode(Date.self, forKey: .dateAdded)
            dateWatched = try container.decodeIfPresent(Date.self, forKey: .dateWatched)
            // Legacy files store rating as a whole Int; accept either.
            if let rating = try? container.decode(Double.self, forKey: .userRating) {
                userRating = rating
            } else if let wholeRating = try? container.decode(Int.self, forKey: .userRating) {
                userRating = Double(wholeRating)
            } else {
                userRating = nil
            }
        }
    }

    /// One show's watched progress: episode records, completed-season snapshots, and the tracked season.
    struct Progress: Codable {
        var tmdbID: Int
        var name: String
        var posterPath: String?
        var isWatched: Bool?
        var isCaughtUp: Bool?
        var watchListOptOut: Bool?
        var tracked: Tracked?
        var seasons: [Season]
        var episodes: [Episode]

        struct Episode: Codable {
            var season: Int
            var episode: Int
            var watchedAt: Date
        }

        struct Season: Codable {
            var season: Int
            var name: String
            var posterPath: String?
            var airDate: Date?
            var episodeCount: Int
            var watchedAt: Date
            var userRating: Double?
        }

        struct Tracked: Codable {
            var season: Int
            var posterPath: String?
            var episodeCount: Int
            var nextEpisodeDate: Date?
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

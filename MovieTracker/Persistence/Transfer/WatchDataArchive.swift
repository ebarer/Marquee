//
//  WatchDataArchive.swift
//  MovieTracker
//
//  A versioned, portable backup snapshot of every list and its entries. Kept
//  independent of the SwiftData `@Model` types so the on-disk format stays stable.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The full contents of the user's lists in a self-contained, Codable form.
struct WatchDataArchive: Codable {
    /// Bumped whenever the on-disk shape changes so importers can refuse files
    /// written by a newer version of the app that they can't understand.
    static let currentVersion = 1

    var version = currentVersion
    var exportedAt = Date()
    var lists: [List]

    /// One list plus the entries it owns.
    struct List: Codable {
        var uuid: UUID
        var name: String
        var symbol: String
        var colorIndex: Int
        /// Raw `Kind` value (the Watch List restores by kind, custom lists by UUID).
        var kind: Int
        var sortOrder: Int
        var createdAt: Date
        var entries: [Entry]
    }

    /// A movie's membership in a list — its display snapshot plus any personal facts.
    struct Entry: Codable {
        var movieID: Int
        var title: String
        var posterPath: String?
        var releaseDate: Date?
        var dateAdded: Date
        var dateWatched: Date?
        /// Personal rating in stars (half-step). Optional so older files without
        /// it still import.
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
            // Accept a decimal rating, or map a whole integer (e.g. legacy
            // whole-star scores) to a Double.
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

extension WatchDataArchive {
    /// ISO-8601 dates and stable key ordering keep the file human-readable and
    /// diff-friendly.
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
        let decoded = try Self.makeDecoder().decode(WatchDataArchive.self, from: data)
        guard decoded.version <= WatchDataArchive.currentVersion else {
            throw ImportError.unsupportedVersion(decoded.version)
        }
        self = decoded
    }
}

/// Reasons an import can fail beyond the system's own file-access errors.
enum ImportError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion:
            return "This backup was created by a newer version of MovieTracker."
        }
    }
}

// MARK: - Import summary

/// The result of merging an archive, surfaced to the user after an import.
struct ImportSummary {
    var listsCreated = 0
    var entriesAdded = 0
    var entriesSkipped = 0

    var message: String {
        var parts: [String] = []
        if listsCreated > 0 {
            parts.append("\(listsCreated) new \(listsCreated == 1 ? "list" : "lists")")
        }
        parts.append("\(entriesAdded) \(entriesAdded == 1 ? "movie" : "movies") added")
        if entriesSkipped > 0 {
            parts.append("\(entriesSkipped) already present")
        }
        return parts.joined(separator: ", ") + "."
    }
}

// MARK: - Document

/// Wraps an archive as a JSON `FileDocument` for `fileExporter`/`fileImporter`.
struct WatchDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var archive: WatchDataArchive

    init(archive: WatchDataArchive) {
        self.archive = archive
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.archive = try WatchDataArchive(json: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try archive.jsonData())
    }
}

// MARK: - Store: export / import

extension WatchDataArchive {
    /// Stable list-kind values for the on-disk format, independent of the app's
    /// runtime model so backups keep importing after schema changes.
    enum Kind: Int {
        case custom = 0
        case toWatch = 1
        case watched = 2
        case viewed = 3
    }

    /// Builds a complete archive of every list plus the Watched facts. The file
    /// format is unchanged from v1 — Watched is emitted as a pseudo-list carrying
    /// each title's watched date and rating — so old backups still import.
    static func export(from context: ModelContext) -> WatchDataArchive {
        var lists = MediaList.all(in: context).map { list in
            WatchDataArchive.List(
                uuid: list.uuid, name: list.name, symbol: list.symbol,
                colorIndex: list.colorIndex,
                kind: list.isWatchList ? Kind.toWatch.rawValue : Kind.custom.rawValue,
                sortOrder: list.sortOrder, createdAt: list.createdAt,
                entries: (list.entries ?? []).map { entry in
                    WatchDataArchive.Entry(
                        movieID: entry.tmdbID, title: entry.title, posterPath: entry.posterPath,
                        releaseDate: entry.releaseDate, dateAdded: entry.addedAt,
                        dateWatched: nil, userRating: nil)
                }
            )
        }

        let watched = (try? context.fetch(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.watchedAt != nil }))) ?? []
        if !watched.isEmpty {
            lists.append(WatchDataArchive.List(
                uuid: UUID(), name: "Watched", symbol: "checkmark.rectangle.stack",
                colorIndex: 0, kind: Kind.watched.rawValue, sortOrder: 2, createdAt: Date(),
                entries: watched.map { item in
                    WatchDataArchive.Entry(
                        movieID: item.tmdbID, title: item.title, posterPath: item.posterPath,
                        releaseDate: item.releaseDate, dateAdded: item.addedAt,
                        dateWatched: item.watchedAt, userRating: item.userRating)
                }))
        }
        return WatchDataArchive(lists: lists)
    }

    /// Merges an archive additively: list memberships become `ListEntry`s, Watched
    /// entries set each title's `MediaItem` facts. Nothing existing is modified.
    @MainActor
    @discardableResult
    static func merge(_ archive: WatchDataArchive, using store: MediaStore) -> ImportSummary {
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
    private static func target(_ archived: WatchDataArchive.List, isWatchList: Bool,
                               using store: MediaStore, summary: inout ImportSummary) -> MediaList? {
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

    private static func movie(from entry: WatchDataArchive.Entry) -> Movie {
        let movie = Movie(id: entry.movieID, title: entry.title)
        movie.poster = entry.posterPath
        movie.releaseDate = entry.releaseDate
        return movie
    }
}

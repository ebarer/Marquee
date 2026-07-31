//
//  WatchDataArchive.swift
//  MovieTracker
//
//  A versioned, portable snapshot of every list and its entries — the shape the
//  app writes to (and reads back from) a backup file the user can export and
//  import. Deliberately independent of the SwiftData `@Model` types so the
//  on-disk format stays stable even if those models change.
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
        /// Raw `ListKind` value (built-in lists restore by kind, custom by UUID).
        var kind: Int
        var sortOrder: Int
        var createdAt: Date
        var entries: [Entry]
    }

    /// A movie's membership in a list, mirroring `WatchListEntry`'s stored fields.
    struct Entry: Codable {
        var movieID: Int
        var title: String
        var posterPath: String?
        var releaseDate: Date?
        var dateAdded: Date
        var dateWatched: Date?
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

extension WatchListStore {
    /// Builds a complete archive of every list and entry, in display order.
    static func exportArchive(from context: ModelContext) -> WatchDataArchive {
        // The Viewed list is transient browse history, not something to back up.
        let lists = allLists(in: context).filter { $0.kind != .viewed }.map { list in
            WatchDataArchive.List(
                uuid: list.uuid,
                name: list.name,
                symbol: list.symbol,
                colorIndex: list.colorIndex,
                kind: list.kindRaw,
                sortOrder: list.sortOrder,
                createdAt: list.createdAt,
                entries: (list.entries ?? []).map { entry in
                    WatchDataArchive.Entry(
                        movieID: entry.movieID,
                        title: entry.title,
                        posterPath: entry.posterPath,
                        releaseDate: entry.releaseDate,
                        dateAdded: entry.dateAdded,
                        dateWatched: entry.dateWatched
                    )
                }
            )
        }
        return WatchDataArchive(lists: lists)
    }

    /// Merges an archive into the current library. Built-in lists match by kind
    /// and custom lists by UUID (creating any that are missing); an entry is
    /// added only when its movie isn't already on the target list. Nothing that
    /// already exists is modified or removed — importing is purely additive.
    @discardableResult
    static func importArchive(_ archive: WatchDataArchive, into context: ModelContext) -> ImportSummary {
        var summary = ImportSummary()
        ensureDefaultLists(in: context)

        for archivedList in archive.lists {
            guard let target = resolveTarget(for: archivedList, in: context, summary: &summary) else {
                continue
            }
            for archivedEntry in archivedList.entries {
                guard entry(for: archivedEntry.movieID, in: target) == nil else {
                    summary.entriesSkipped += 1
                    continue
                }
                insertEntry(archivedEntry, into: target, in: context)
                summary.entriesAdded += 1
            }
        }
        return summary
    }

    /// Finds (or, for a missing custom list, creates) the local list an archived
    /// list should merge into.
    private static func resolveTarget(for archived: WatchDataArchive.List,
                                      in context: ModelContext,
                                      summary: inout ImportSummary) -> MovieList? {
        let kind = ListKind(rawValue: archived.kind) ?? .custom
        switch kind {
        case .toWatch, .watched, .viewed:
            return list(kind: kind, in: context)
        case .custom:
            if let existing = allLists(in: context).first(where: { $0.uuid == archived.uuid }) {
                return existing
            }
            let created = MovieList(name: archived.name, symbol: archived.symbol,
                                    kind: .custom, sortOrder: archived.sortOrder,
                                    colorIndex: archived.colorIndex)
            // Preserve the original identity/date so re-importing stays idempotent.
            created.uuid = archived.uuid
            created.createdAt = archived.createdAt
            context.insert(created)
            summary.listsCreated += 1
            return created
        }
    }

    /// Inserts an archived entry into a list, preserving its original dates.
    private static func insertEntry(_ archived: WatchDataArchive.Entry,
                                    into list: MovieList, in context: ModelContext) {
        let entry = WatchListEntry(movie: Movie(id: archived.movieID, title: archived.title))
        entry.posterPath = archived.posterPath
        entry.releaseDate = archived.releaseDate
        entry.dateAdded = archived.dateAdded
        entry.dateWatched = archived.dateWatched
        entry.list = list
        context.insert(entry)
    }
}

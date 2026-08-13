//
//  LibraryBackupDocument.swift
//  MovieTracker
//

import SwiftUI
import UniformTypeIdentifiers

enum ImportError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion:
            return "This backup was created by a newer version of Marqee."
        }
    }
}

// MARK: - Import summary

struct ImportSummary {
    var listsCreated = 0
    var entriesAdded = 0
    var entriesSkipped = 0

    var message: String {
        var parts: [String] = []
        if listsCreated > 0 {
            parts.append("\(listsCreated) new \(listsCreated == 1 ? "list" : "lists")")
        }
        parts.append("\(entriesAdded) \(entriesAdded == 1 ? "title" : "titles") added")
        if entriesSkipped > 0 {
            parts.append("\(entriesSkipped) already present")
        }
        return parts.joined(separator: ", ") + "."
    }
}

// MARK: - Document

struct LibraryBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var archive: LibraryBackup

    init(archive: LibraryBackup) {
        self.archive = archive
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.archive = try LibraryBackup(json: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try archive.jsonData())
    }
}

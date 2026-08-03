//
//  ImportExportCoordinator.swift
//  MovieTracker
//

import SwiftUI

/// Owns the backup import/export workflow — choosing files, merging archives/CSV,
/// and the presentation state the sheets and alerts bind to. Keeps that business
/// logic out of `ListManagerView`, which just presents what this exposes.
@MainActor
@Observable
final class ImportExportCoordinator {
    var showExporter = false
    var showImporter = false
    private(set) var exportDocument: LibraryBackupDocument?

    var importSummary: ImportSummary?
    var transferError: String?
    /// Non-nil while a CSV import is fetching movie details, as `(fetched, total)`.
    private(set) var importProgress: (done: Int, total: Int)?

    /// Backup filename with today's date, e.g. "MovieTracker Backup 2026-08-02.json".
    var exportFilename: String {
        let stamp = Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "MovieTracker Backup \(stamp).json"
    }

    func prepareExport(using store: MediaStore) {
        exportDocument = LibraryBackupDocument(archive: store.exportArchive())
        showExporter = true
    }

    /// Routes a picked file to the archive or CSV importer by extension.
    func handleImport(_ result: Result<URL, Error>, using store: MediaStore) {
        switch result {
        case .success(let url):
            if url.pathExtension.lowercased() == "csv" {
                importCSV(from: url, using: store)
            } else {
                importArchive(from: url, using: store)
            }
        case .failure(let error):
            transferError = error.localizedDescription
        }
    }

    private func importArchive(from url: URL, using store: MediaStore) {
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let archive = try LibraryBackup(json: try Data(contentsOf: url))
            importSummary = LibraryBackup.merge(archive, using: store)
        } catch {
            transferError = error.localizedDescription
        }
    }

    private func importCSV(from url: URL, using store: MediaStore) {
        let records: [CSVMovieRecord]
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            records = try CSVMovieRecord.parse(data: try Data(contentsOf: url))
        } catch {
            transferError = error.localizedDescription
            return
        }

        guard !records.isEmpty else {
            transferError = "No movies found in the CSV file."
            return
        }

        importProgress = (done: 0, total: records.count)
        Task {
            let summary = await CSVMovieRecord.merge(records, using: store) { done, total in
                self.importProgress = (done: done, total: total)
            }
            importProgress = nil
            importSummary = summary
        }
    }
}

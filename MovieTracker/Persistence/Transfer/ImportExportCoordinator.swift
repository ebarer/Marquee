//
//  ImportExportCoordinator.swift
//  MovieTracker
//

import SwiftUI

/// Owns the backup import/export workflow and the presentation state its sheets bind to.
@MainActor
@Observable
final class ImportExportCoordinator {
    static let shared = ImportExportCoordinator()
    private init() {}

    var showExporter = false
    var showImporter = false
    private(set) var exportDocument: LibraryBackupDocument?

    var importSummary: ImportSummary?
    var transferError: String?
    private(set) var importProgress: (done: Int, total: Int)?

    var exportFilename: String {
        let stamp = Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "Marquee Backup \(stamp).json"
    }

    func prepareExport(using store: PersistenceCoordinator) {
        exportDocument = LibraryBackupDocument(archive: LibraryBackup.export(from: store.context))
        showExporter = true
    }

    func handleImport(_ result: Result<URL, Error>, using store: PersistenceCoordinator) {
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

    private func importArchive(from url: URL, using store: PersistenceCoordinator) {
        let archive: LibraryBackup
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            archive = try LibraryBackup(json: try Data(contentsOf: url))
        } catch {
            transferError = error.localizedDescription
            return
        }
        run { progress in await LibraryBackup.merge(archive, using: store, progress: progress) }
    }

#if targetEnvironment(simulator)
    func populate(using store: PersistenceCoordinator) {
        run { progress in
            guard let summary = await SimulatorTools.populate(using: store, progress: progress) else {
                self.transferError = "Sample data is missing from this build."
                return nil
            }
            return summary
        }
    }
#endif

    private func importCSV(from url: URL, using store: PersistenceCoordinator) {
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

        run { progress in await CSVMovieRecord.merge(records, using: store, progress: progress) }
    }

    private func run(_ merge: @escaping ((Int, Int) -> Void) async -> ImportSummary?) {
        guard importProgress == nil else { return }
        importProgress = (done: 0, total: 1)
        Task {
            let summary = await merge { done, total in
                self.importProgress = (done: done, total: total)
            }
            importProgress = nil
            importSummary = summary
        }
    }
}

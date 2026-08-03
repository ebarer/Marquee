//
//  BackupTransfer.swift
//  MovieTracker
//

import SwiftUI
import UniformTypeIdentifiers

/// The file exporter, importer, and their result alerts, kept out of
/// `ListsView.body` so its main modifier chain stays type-checkable.
struct BackupTransferModifier: ViewModifier {
    @Binding var showExporter: Bool
    @Binding var showImporter: Bool
    let exportDocument: LibraryBackupDocument?
    let exportFilename: String
    @Binding var importSummary: ImportSummary?
    @Binding var transferError: String?
    /// Non-nil while a CSV import is fetching movie details, as `(fetched, total)`.
    let importProgress: (done: Int, total: Int)?
    let onImport: (Result<URL, Error>) -> Void

    func body(content: Content) -> some View {
        content
            .fileExporter(isPresented: $showExporter, document: exportDocument,
                          contentType: .json, defaultFilename: exportFilename) { result in
                if case .failure(let error) = result {
                    transferError = error.localizedDescription
                }
            }
            // JSON is the app's own backup format; CSV is a TodoMovies export.
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.json, .commaSeparatedText],
                          onCompletion: onImport)
            .overlay {
                if let importProgress {
                    ImportProgressOverlay(done: importProgress.done, total: importProgress.total)
                }
            }
            .alert("Import Complete", isPresented: importCompleteBinding, presenting: importSummary) { _ in
                Button("OK", role: .cancel) {}
            } message: { summary in
                Text(summary.message)
            }
            .alert("Something Went Wrong", isPresented: transferErrorBinding, presenting: transferError) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
    }

    private var importCompleteBinding: Binding<Bool> {
        Binding(get: { importSummary != nil }, set: { if !$0 { importSummary = nil } })
    }

    private var transferErrorBinding: Binding<Bool> {
        Binding(get: { transferError != nil }, set: { if !$0 { transferError = nil } })
    }
}

/// A determinate blocking card shown while a CSV import fetches details from TMDB.
private struct ImportProgressOverlay: View {
    let done: Int
    let total: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .progressViewStyle(.linear)
                    .frame(width: 200)
                Text("Importing \(done) of \(total)…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview("Import progress") {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        ImportProgressOverlay(done: 37, total: 120)
    }
    .preferredColorScheme(.dark)
}

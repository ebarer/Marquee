//
//  BackupTransfer.swift
//  MovieTracker
//

import SwiftUI
import UniformTypeIdentifiers

/// Surfaces the `ImportExportCoordinator`'s state as file pickers, a progress
/// overlay, and result alerts — the SwiftUI presentation that can't live on the
/// coordinator itself. Kept out of `ListManagerView.body` so its modifier chain
/// stays type-checkable. `onImport` is a closure because handling a picked file
/// needs the store, which the view holds.
struct BackupTransferModifier: ViewModifier {
    @Bindable var coordinator = ImportExportCoordinator.shared
    let onImport: (Result<URL, Error>) -> Void

    func body(content: Content) -> some View {
        content
            .fileExporter(isPresented: $coordinator.showExporter, document: coordinator.exportDocument,
                          contentType: .json, defaultFilename: coordinator.exportFilename) { result in
                if case .failure(let error) = result {
                    coordinator.transferError = error.localizedDescription
                }
            }
            // JSON is the app's own backup format; CSV is a TodoMovies export.
            .fileImporter(isPresented: $coordinator.showImporter,
                          allowedContentTypes: [.json, .commaSeparatedText],
                          onCompletion: onImport)
            .overlay {
                if let progress = coordinator.importProgress {
                    ImportProgressOverlay(done: progress.done, total: progress.total)
                }
            }
            .alert("Import Complete", isPresented: importCompleteBinding, presenting: coordinator.importSummary) { _ in
                Button("OK", role: .cancel) {}
            } message: { summary in
                Text(summary.message)
            }
            .alert("Something Went Wrong", isPresented: transferErrorBinding, presenting: coordinator.transferError) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
    }

    private var importCompleteBinding: Binding<Bool> {
        Binding(get: { coordinator.importSummary != nil }, set: { if !$0 { coordinator.importSummary = nil } })
    }

    private var transferErrorBinding: Binding<Bool> {
        Binding(get: { coordinator.transferError != nil }, set: { if !$0 { coordinator.transferError = nil } })
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

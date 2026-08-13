//
//  BackupTransfer.swift
//  MovieTracker
//

import SwiftUI
import UniformTypeIdentifiers

/// Surfaces the `ImportExportCoordinator`'s state as file pickers, a progress overlay, and result alerts.
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

#Preview("Backup transfer chrome") {
    Color.appBackground
        .ignoresSafeArea()
        .modifier(BackupTransferModifier { _ in })
        .preferredColorScheme(.dark)
}

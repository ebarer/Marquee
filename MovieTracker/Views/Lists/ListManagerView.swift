//
//  ListManagerView.swift
//  MovieTracker
//
//  A modal for reordering, deleting, and editing custom lists. The Watch List,
//  Watched, and Viewed are shown for context (with counts) but pinned and inert.
//

import SwiftUI
import SwiftData

struct ListManagerView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @Query private var trackedItems: [MediaItem]
    @Environment(MediaStore.self) private var store: MediaStore?

    private var visibleLists: [MediaList] { lists.filter { !$0.isDeduplicated } }
    private var watchList: MediaList? { visibleLists.first { $0.isWatchList } }
    private var customLists: [MediaList] { visibleLists.filter { !$0.isWatchList } }

    private var watchedCount: Int { trackedItems.lazy.filter { $0.watchedAt != nil }.count }
    private var viewedCount: Int { trackedItems.lazy.filter { $0.lastViewedAt != nil }.count }

    @State private var editing: MediaList?
    @State private var creatingNew = false

    // Backup import/export state.
    @State private var exportDocument: WatchDataDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importSummary: ImportSummary?
    @State private var transferError: String?
    @State private var importProgress: (done: Int, total: Int)?

    private static let separator = Color.white.opacity(0.25)

    var body: some View {
        NavigationStack {
            List {
                // Built-in views pinned at the top — shown for context, not editable.
                Section {
                    if let watchList {
                        row(for: watchList, editable: false)
                            .moveDisabled(true)
                            .deleteDisabled(true)
                    }
                    virtualRow(title: "Watched", symbol: "checkmark.rectangle.stack",
                               color: Color(red255: 90, green255: 200, blue255: 250), count: watchedCount)
                }

                // Custom lists: reorderable and deletable.
                Section {
                    if customLists.isEmpty {
                        Text("No custom lists yet")
                            .foregroundStyle(.secondary)
                            .moveDisabled(true)
                            .deleteDisabled(true)
                    } else {
                        ForEach(customLists) { list in
                            row(for: list, editable: true)
                        }
                        .onDelete(perform: delete)
                        .onMove(perform: move)
                    }
                }

                // The Viewed history pinned at the bottom.
                Section {
                    virtualRow(title: "Viewed", symbol: "clock.arrow.circlepath",
                               color: .gray, count: viewedCount)
                }

                // Library-wide actions (not lists) — tinted accent to set them apart,
                // with the app version pinned to the footer.
                Section {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                            .foregroundStyle(Color.appAccent)
                    }
                    Button {
                        prepareExport()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .foregroundStyle(Color.appAccent)
                    }
                } footer: {
                    Text(appInfo)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .listRowSeparatorTint(Self.separator)
                .moveDisabled(true)
                .deleteDisabled(true)
            }
            .listStyle(.insetGrouped)
            // The whole point of this screen is reordering/deleting, so it stays in
            // edit mode permanently rather than gating that behind an Edit button.
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Edit Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        creatingNew = true
                    } label: {
                        Label("New List", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { dismiss() }
                }
            }
            .sheet(item: $editing) { list in
                NavigationStack {
                    ListEditorView(existing: list)
                }
            }
            .sheet(isPresented: $creatingNew) {
                NavigationStack {
                    // Custom lists sit after the Watch List (order 0).
                    ListEditorView(existing: nil, nextSortOrder: 1 + customLists.count)
                }
            }
            .modifier(BackupTransferModifier(
                showExporter: $showExporter,
                showImporter: $showImporter,
                exportDocument: exportDocument,
                exportFilename: exportFilename,
                importSummary: $importSummary,
                transferError: $transferError,
                importProgress: importProgress,
                onImport: handleImport
            ))
        }
    }

    // MARK: - Rows

    private func row(for list: MediaList, editable: Bool) -> some View {
        HStack(spacing: 0) {
            ListIcon(list, size: 38, symbolSize: 18)
                .padding(.trailing, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                    .foregroundStyle(.primary)
                Text(countText((list.entries ?? []).count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }

            Spacer(minLength: 12)

            if editable {
                Button {
                    editing = list
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .fontWeight(.light)
                }
                .buttonStyle(.borderless)

                // Full-height reorder-gutter line echoing the UIKit reorder divider.
                Rectangle()
                    .fill(Self.separator)
                    .frame(width: 1)
                    .padding(.horizontal, 14)
            }
        }
        .frame(minHeight: 60)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: editable ? 0 : 20))
        .listRowSeparatorTint(Self.separator)
    }

    /// An inert row for a derived view (Watched / Viewed), shown for context.
    private func virtualRow(title: String, symbol: String, color: Color, count: Int) -> some View {
        HStack(spacing: 0) {
            ListIcon(symbol: symbol, color: color, size: 38, symbolSize: 18)
                .padding(.trailing, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(countText(count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }

            Spacer(minLength: 12)
        }
        .frame(minHeight: 60)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .listRowSeparatorTint(Self.separator)
        .moveDisabled(true)
        .deleteDisabled(true)
    }

    private func countText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "movie" : "movies")"
    }

    /// App version/build, e.g. "1.2 (34)", shown in the actions footer.
    private var appInfo: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        switch (version, build) {
        case let (version?, build?): return "\(version) (\(build))"
        case let (version?, nil): return version
        case let (nil, build?): return build
        default: return ""
        }
    }

    // MARK: - Actions

    private func delete(at offsets: IndexSet) {
        offsets.map { customLists[$0] }.forEach { store?.delete($0) }
    }

    /// Reorders custom lists and rewrites their sort orders (starting at 1, after
    /// the Watch List at 0).
    private func move(from source: IndexSet, to destination: Int) {
        store?.perform {
            var reordered = customLists
            reordered.move(fromOffsets: source, toOffset: destination)
            for (index, list) in reordered.enumerated() {
                list.sortOrder = 1 + index
            }
        }
    }

    // MARK: - Backup import/export

    private var exportFilename: String {
        let stamp = Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "MovieTracker Backup \(stamp)"
    }

    private func prepareExport() {
        guard let store else { return }
        exportDocument = WatchDataDocument(archive: store.exportArchive())
        showExporter = true
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            if url.pathExtension.lowercased() == "csv" {
                importCSV(from: url)
            } else {
                importArchive(from: url)
            }
        case .failure(let error):
            transferError = error.localizedDescription
        }
    }

    private func importArchive(from url: URL) {
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let archive = try WatchDataArchive(json: try Data(contentsOf: url))
            if let store { importSummary = WatchDataArchive.merge(archive, using: store) }
        } catch {
            transferError = error.localizedDescription
        }
    }

    private func importCSV(from url: URL) {
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

        guard let store else { return }
        importProgress = (done: 0, total: records.count)
        Task {
            let summary = await CSVMovieRecord.merge(records, using: store) { done, total in
                importProgress = (done: done, total: total)
            }
            importProgress = nil
            importSummary = summary
        }
    }
}

#Preview {
    ListManagerView()
        .modelContainer(previewModelContainer)
        .environment(MediaStore(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}

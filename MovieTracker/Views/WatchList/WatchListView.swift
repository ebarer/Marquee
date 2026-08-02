//
//  WatchListView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData
import CoreData

struct WatchListView: View {
    @Environment(\.modelContext) private var context
    /// Present only when running inside the app (absent in previews).
    @Environment(CloudSyncMonitor.self) private var syncMonitor: CloudSyncMonitor?
    @Query(sort: [SortDescriptor(\MovieList.sortOrder), SortDescriptor(\MovieList.createdAt)])
    private var allLists: [MovieList]

    /// The queried lists with duplicate built-in lists collapsed, so the switcher
    /// never shows two "Watch List"/"Watched"/"Viewed" entries in the window where
    /// CloudKit has synced a duplicate but `deduplicateBuiltInLists` hasn't merged
    /// it away yet. For each built-in kind only the canonical (lowest-UUID) list —
    /// the merge survivor — is kept; custom lists pass through unchanged.
    private var lists: [MovieList] {
        let visible = allLists.filter { !$0.isDeduplicated }
        var canonicalID: [ListKind: UUID] = [:]
        for list in visible where list.kind != .custom {
            if let winner = canonicalID[list.kind], winner.uuidString <= list.uuid.uuidString {
                continue
            }
            canonicalID[list.kind] = list.uuid
        }
        return visible.filter { $0.kind == .custom || canonicalID[$0.kind] == $0.uuid }
    }

    @State private var selectedListUUID: UUID?
    @State private var editor: ListEditor?

    /// Month/year sections for the selected list, built off the main thread by
    /// `SectionBuilder` so grouping a large list never blocks the UI.
    @State private var sections: [SectionSnapshot] = []
    @State private var builder: SectionBuilder?

    /// Bumped on any store change (local save or CloudKit import) so the sections
    /// rebuild even when the entry count is unchanged (e.g. a watched-date edit).
    @State private var dataVersion = 0

    @State private var filterText = ""

    // Sort direction is remembered per list (keyed by UUID in UserDefaults):
    // Watched defaults to descending, every other list to ascending.
    @State private var sortAscending = true
    @AppStorage("watchedSortKey") private var watchedSortKey: WatchedSortKey = .releaseDate

    // Backup import/export state.
    @State private var exportDocument: WatchDataDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importSummary: ImportSummary?
    @State private var transferError: String?
    /// Progress of an in-flight CSV import (fetched, total); nil when idle.
    @State private var importProgress: (done: Int, total: Int)?

    @State private var showListManager = false

    var body: some View {
        WatchListRows(sections: sections, list: selectedList, lists: lists, context: context,
                      listColor: activeListColor, watchList: watchList, watchedList: watchedList)
        .listStyle(.plain)
        .tint(activeListColor)
        .navigationTitle(selectedList?.name ?? "Lists")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            // Rendered ourselves so the list name can carry the list's color.
            ToolbarItem(placement: .principal) {
                Menu {
                    WatchListTitleMenu(selection: $selectedListUUID, topLists: topLists,
                                       customLists: customLists, viewedList: viewedList)
                } label: {
                    WatchListTitleLabel(name: selectedList?.name ?? "Lists",
                                        color: activeListColor, movieCount: movieCount)
                }
                .tint(.primary)
            }
            ToolbarItem(placement: .topBarLeading) {
                WatchListActionsMenu(
                    canEditLists: !customLists.isEmpty,
                    clearableList: clearableViewedList,
                    onNewList: { editor = .create(addMovie: nil) },
                    onEditLists: { showListManager = true },
                    onClear: { WatchListStore.clear($0, in: context) },
                    onImport: { showImporter = true },
                    onExport: { prepareExport() }
                )
                .tint(activeListColor)
            }
            if syncMonitor?.isSyncing == true {
                ToolbarItem(placement: .topBarTrailing) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(activeListColor)
                        .accessibilityLabel("Syncing with iCloud")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                WatchListSortMenu(ascending: $sortAscending, watchedSortKey: $watchedSortKey,
                                  tracksWatchedDate: selectedList?.tracksWatchedDate == true)
                    .tint(activeListColor)
            }
        }
        .searchable(text: $filterText, prompt: "Search \(selectedList?.name ?? "list")")
        .overlay {
            if let list = selectedList, (list.entries ?? []).isEmpty {
                ContentUnavailableView {
                    Label {
                        Text(list.name)
                    } icon: {
                        ListIcon(symbol: list.symbol, color: listColor(for: list), size: 64)
                    }
                } description: {
                    Text(emptyMessage(for: list))
                }
            } else if !filterText.isEmpty, sections.isEmpty {
                ContentUnavailableView.search(text: filterText)
            }
        }
        .sheet(item: $editor) { mode in
            NavigationStack {
                ListEditorView(
                    existing: mode.list,
                    nextSortOrder: (lists.map(\.sortOrder).max() ?? 1) + 1,
                    onSaved: { newList in
                        // If invoked from a movie's context menu, add it to the new list.
                        if let movie = mode.movieToAdd {
                            WatchListStore.add(movie, to: newList, in: context)
                        }
                        select(newList)
                    },
                    onDeleted: { select(WatchListStore.list(kind: .toWatch, in: context)) }
                )
            }
        }
        .sheet(isPresented: $showListManager) {
            ListManagerView()
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
        .task(id: sectionsInput) { await rebuildSections() }
        // A local save (e.g. a watched-date edit) that doesn't change the entry count
        // still needs a rebuild. Scoped to the main context so background churn elsewhere
        // doesn't spuriously fire.
        .task {
            for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave, object: context) {
                dataVersion &+= 1
            }
        }
        // A CloudKit import lands as a remote store change with no local save.
        .task {
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                dataVersion &+= 1
            }
        }
        .onAppear { selectDefaultIfNeeded() }
        // Seeding is deferred to app launch (RootView); pick the Watch List as soon
        // as the lists arrive.
        .onChange(of: lists.count) { _, _ in selectDefaultIfNeeded() }
        .onChange(of: selectedListUUID) { _, _ in
            // Clear immediately so the previous list's rows never show under the new
            // title while the async rebuild runs.
            sections = []
            loadSort()
        }
        .onChange(of: sortAscending) { _, newValue in
            guard let list = selectedList else { return }
            UserDefaults.standard.set(newValue, forKey: Self.sortKey(for: list))
        }
    }

    // MARK: - Per-list sort direction

    private static func sortKey(for list: MovieList) -> String {
        "watchListSortAscending_\(list.uuid.uuidString)"
    }

    /// Loads the stored sort direction, falling back to the per-kind default
    /// (Watched/Viewed newest-first, everything else oldest-first).
    private func loadSort() {
        guard let list = selectedList else { return }
        if let stored = UserDefaults.standard.object(forKey: Self.sortKey(for: list)) as? Bool {
            sortAscending = stored
        } else {
            sortAscending = list.kind != .watched && list.kind != .viewed
        }
    }

    // MARK: - Backup import/export

    /// A dated, filesystem-safe default name for the exported backup file.
    private var exportFilename: String {
        let stamp = Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "MovieTracker Backup \(stamp)"
    }

    private func prepareExport() {
        exportDocument = WatchDataDocument(archive: WatchListStore.exportArchive(from: context))
        showExporter = true
    }

    /// Routes the chosen file to the JSON backup or CSV (TodoMovies) importer, then
    /// surfaces the result or an error.
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
            importSummary = WatchListStore.importArchive(archive, into: context)
        } catch {
            transferError = error.localizedDescription
        }
    }

    /// Parses a TodoMovies CSV, then merges it while fetching each movie's details
    /// from TMDB behind the progress overlay.
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

        importProgress = (done: 0, total: records.count)
        Task {
            let summary = await WatchListStore.importCSV(records, into: context) { done, total in
                importProgress = (done: done, total: total)
            }
            importProgress = nil
            importSummary = summary
        }
    }

    // MARK: - Selection

    private var selectedList: MovieList? {
        if let id = selectedListUUID, let match = lists.first(where: { $0.uuid == id }) {
            return match
        }
        return lists.first { $0.kind == .toWatch } ?? lists.first
    }

    private var movieCount: Int { (selectedList?.entries ?? []).count }
    private var topLists: [MovieList] { lists.filter { $0.kind == .toWatch || $0.kind == .watched } }
    private var customLists: [MovieList] { lists.filter { $0.kind == .custom } }
    private var viewedList: MovieList? { lists.first { $0.kind == .viewed } }
    private var watchList: MovieList? { lists.first { $0.kind == .toWatch } }
    private var watchedList: MovieList? { lists.first { $0.kind == .watched } }

    /// The Viewed list when it can be cleared (selected and non-empty); else nil.
    private var clearableViewedList: MovieList? {
        guard let list = selectedList, list.kind == .viewed, !(list.entries ?? []).isEmpty else { return nil }
        return list
    }

    private func listColor(for list: MovieList) -> Color { list.color }
    private var activeListColor: Color { selectedList.map(listColor) ?? .appAccent }

    private func select(_ list: MovieList?) {
        selectedListUUID = list?.uuid
    }

    /// Defaults the selection to the Watch List once lists are available.
    private func selectDefaultIfNeeded() {
        guard selectedListUUID == nil else { return }
        selectedListUUID = lists.first { $0.kind == .toWatch }?.uuid
    }

    // MARK: - Data

    /// The inputs that determine `sections`; drives the `.task(id:)` rebuild so the
    /// grouping only reruns (off the main thread) when one of these changes.
    private struct SectionsInput: Equatable {
        var listID: UUID?
        var count: Int
        var dataVersion: Int
        var ascending: Bool
        var filter: String
        var watchedSortKey: WatchedSortKey
    }

    private var sectionsInput: SectionsInput {
        SectionsInput(
            listID: selectedList?.uuid,
            count: (selectedList?.entries ?? []).count,
            dataVersion: dataVersion,
            ascending: sortAscending,
            filter: filterText,
            watchedSortKey: watchedSortKey
        )
    }

    private func sortField(for list: MovieList) -> EntrySortField {
        if list.kind == .viewed { return .dateAdded }
        if list.tracksWatchedDate, watchedSortKey == .dateWatched { return .dateWatched }
        return .releaseDate
    }

    /// Rebuilds `sections` on a background context via a lazily-created builder.
    private func rebuildSections() async {
        guard let list = selectedList else {
            sections = []
            return
        }

        let builder = builder ?? SectionBuilder(modelContainer: context.container)
        if self.builder == nil { self.builder = builder }

        let result = await builder.build(
            listID: list.uuid,
            sortField: sortField(for: list),
            ascending: sortAscending,
            filter: filterText
        )
        // The task is cancelled and rerun when inputs change, so a late result can't
        // clobber a newer selection — bail on cancel to skip a redundant assignment.
        guard !Task.isCancelled else { return }
        sections = result
    }

    private func emptyMessage(for list: MovieList) -> String {
        switch list.kind {
        case .toWatch: return "Movies you want to watch will appear here."
        case .watched: return "Movies you have watched will appear here."
        case .viewed: return "Movies you browse will appear here."
        case .custom: return "Movies you add to “\(list.name)” will appear here."
        }
    }

    /// Drives the create/edit sheet.
    private enum ListEditor: Identifiable {
        case create(addMovie: Movie?)
        case edit(MovieList)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let list): return list.uuid.uuidString
            }
        }

        var list: MovieList? {
            switch self {
            case .create: return nil
            case .edit(let list): return list
            }
        }

        var movieToAdd: Movie? {
            if case .create(let movie) = self { return movie }
            return nil
        }
    }
}

#Preview("Idle") {
    NavigationStack {
        WatchListView()
            .movieTrackerDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(CloudSyncMonitor(isSyncing: false))
    .preferredColorScheme(.dark)
}

#Preview("Syncing") {
    NavigationStack {
        WatchListView()
            .movieTrackerDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(CloudSyncMonitor(isSyncing: true))
    .preferredColorScheme(.dark)
}

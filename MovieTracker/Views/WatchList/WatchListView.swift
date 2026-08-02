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
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var allLists: [MediaList]

    /// Live lists with any duplicate Watch List collapsed to the canonical copy.
    private var lists: [MediaList] {
        let visible = allLists.filter { !$0.isDeduplicated }
        let canonicalWatch = visible.filter { $0.isWatchList }
            .sorted { $0.uuid.uuidString < $1.uuid.uuidString }.first
        return visible.filter { !$0.isWatchList || $0.uuid == canonicalWatch?.uuid }
    }

    /// The current view; nil until the Watch List is chosen on appear.
    @State private var selection: ListSelection?
    @State private var editor: ListEditor?

    @State private var sections: [SectionSnapshot] = []
    @State private var builder: SectionBuilder?
    /// Bumped on any store change so the sections rebuild even when a count is
    /// unchanged (e.g. a watched-date edit).
    @State private var dataVersion = 0
    @State private var filterText = ""

    @AppStorage("watchedListAscending") private var watchedAscending = false
    @AppStorage("viewedListAscending") private var viewedAscending = false
    @AppStorage("watchedSortKey") private var watchedSortKey: WatchedSortKey = .releaseDate

    // Backup import/export state.
    @State private var exportDocument: WatchDataDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importSummary: ImportSummary?
    @State private var transferError: String?
    @State private var importProgress: (done: Int, total: Int)?

    @State private var showListManager = false

    var body: some View {
        WatchListRows(sections: sections, selection: resolvedSelection, lists: lists,
                      context: context, listColor: activeColor)
        .listStyle(.plain)
        .tint(activeColor)
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Menu {
                    WatchListTitleMenu(selection: selectionBinding, watchList: watchList,
                                       customLists: customLists)
                } label: {
                    WatchListTitleLabel(name: title, color: activeColor, count: movieCount)
                }
                .tint(.primary)
            }
            ToolbarItem(placement: .topBarLeading) {
                WatchListActionsMenu(
                    canEditLists: !customLists.isEmpty,
                    canClearViewed: resolvedSelection == .viewed && movieCount > 0,
                    onNewList: { editor = .create(addMovie: nil) },
                    onEditLists: { showListManager = true },
                    onClearViewed: clearViewed,
                    onImport: { showImporter = true },
                    onExport: prepareExport
                )
                .tint(activeColor)
            }
            if syncMonitor?.isSyncing == true {
                ToolbarItem(placement: .topBarTrailing) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(activeColor)
                        .accessibilityLabel("Syncing with iCloud")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                WatchListSortMenu(ascending: ascendingBinding, watchedSortKey: $watchedSortKey,
                                  showsWatchedSortKey: resolvedSelection == .watched)
                    .tint(activeColor)
            }
        }
        .searchable(text: $filterText, prompt: "Search \(title)")
        .overlay {
            if sections.isEmpty {
                if !filterText.isEmpty {
                    ContentUnavailableView.search(text: filterText)
                } else {
                    emptyState
                }
            }
        }
        .sheet(item: $editor) { mode in
            NavigationStack {
                ListEditorView(
                    existing: mode.list,
                    nextSortOrder: (customLists.map(\.sortOrder).max() ?? 0) + 1,
                    onSaved: { newList in
                        if let movie = mode.movieToAdd { newList.add(movie) }
                        selection = .list(newList.uuid)
                    },
                    onDeleted: { selection = watchList.map { .list($0.uuid) } }
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
        // A local save (e.g. a watched-date edit) that doesn't change a count still
        // needs a rebuild. Scoped to the main context.
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
        .onChange(of: lists.count) { _, _ in selectDefaultIfNeeded() }
        .onChange(of: selection) { _, _ in sections = [] }
    }

    // MARK: - Selection

    private var resolvedSelection: ListSelection { selection ?? defaultSelection }
    private var defaultSelection: ListSelection { watchList.map { .list($0.uuid) } ?? .watched }

    private var selectionBinding: Binding<ListSelection> {
        Binding(get: { resolvedSelection }, set: { selection = $0 })
    }

    private var watchList: MediaList? { lists.first { $0.isWatchList } }
    private var customLists: [MediaList] { lists.filter { !$0.isWatchList } }
    private func list(_ uuid: UUID) -> MediaList? { lists.first { $0.uuid == uuid } }

    private func selectDefaultIfNeeded() {
        guard selection == nil, let watch = watchList else { return }
        selection = .list(watch.uuid)
    }

    // MARK: - Derived per-selection

    private var title: String {
        switch resolvedSelection {
        case .list(let uuid): return list(uuid)?.name ?? "Lists"
        case .watched: return "Watched"
        case .viewed: return "Viewed"
        }
    }

    private var activeColor: Color {
        switch resolvedSelection {
        case .list(let uuid): return list(uuid)?.color ?? .appAccent
        case .watched: return Color(red255: 90, green255: 200, blue255: 250)
        case .viewed: return .gray
        }
    }

    private var movieCount: Int {
        switch resolvedSelection {
        case .list(let uuid): return (list(uuid)?.entries ?? []).count
        case .watched: return (try? context.fetchCount(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.watchedAt != nil }))) ?? 0
        case .viewed: return (try? context.fetchCount(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.lastViewedAt != nil }))) ?? 0
        }
    }

    private var currentAscending: Bool {
        switch resolvedSelection {
        case .list(let uuid): return list(uuid)?.sortAscending ?? true
        case .watched: return watchedAscending
        case .viewed: return viewedAscending
        }
    }

    private var ascendingBinding: Binding<Bool> {
        Binding(get: { currentAscending }, set: { setAscending($0) })
    }

    private func setAscending(_ value: Bool) {
        switch resolvedSelection {
        case .list(let uuid): list(uuid)?.sortAscending = value
        case .watched: watchedAscending = value
        case .viewed: viewedAscending = value
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch resolvedSelection {
        case .list(let uuid):
            if let list = list(uuid) {
                ContentUnavailableView {
                    Label {
                        Text(list.name)
                    } icon: {
                        ListIcon(list, size: 64)
                    }
                } description: {
                    Text(list.isWatchList
                         ? "Movies you want to watch will appear here."
                         : "Movies you add to “\(list.name)” will appear here.")
                }
            }
        case .watched:
            ContentUnavailableView("Watched", systemImage: "checkmark.rectangle.stack",
                                   description: Text("Movies you mark watched will appear here."))
        case .viewed:
            ContentUnavailableView("Viewed", systemImage: "clock.arrow.circlepath",
                                   description: Text("Movies you browse will appear here."))
        }
    }

    // MARK: - Data

    private var sectionSource: SectionSource? {
        switch resolvedSelection {
        case .list(let uuid): return list(uuid) != nil ? .list(uuid) : nil
        case .watched: return .watched(byWatchedDate: watchedSortKey == .dateWatched)
        case .viewed: return .viewed
        }
    }

    private struct SectionsInput: Equatable {
        var selection: ListSelection
        var count: Int
        var dataVersion: Int
        var ascending: Bool
        var filter: String
        var watchedSortKey: WatchedSortKey
    }

    private var sectionsInput: SectionsInput {
        SectionsInput(selection: resolvedSelection, count: movieCount, dataVersion: dataVersion,
                      ascending: currentAscending, filter: filterText, watchedSortKey: watchedSortKey)
    }

    private func rebuildSections() async {
        guard let source = sectionSource else {
            sections = []
            return
        }
        let builder = builder ?? SectionBuilder(modelContainer: context.container)
        if self.builder == nil { self.builder = builder }

        let result = await builder.build(source: source, ascending: currentAscending, filter: filterText)
        guard !Task.isCancelled else { return }
        sections = result
    }

    private func clearViewed() {
        let items = (try? context.fetch(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.lastViewedAt != nil }))) ?? []
        for item in items {
            item.lastViewedAt = nil
            item.pruneIfEmpty()
        }
    }

    // MARK: - Backup import/export

    private var exportFilename: String {
        let stamp = Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "MovieTracker Backup \(stamp)"
    }

    private func prepareExport() {
        exportDocument = WatchDataDocument(archive: WatchDataArchive.export(from: context))
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
            importSummary = WatchDataArchive.merge(archive, into: context)
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

        importProgress = (done: 0, total: records.count)
        Task {
            let summary = await CSVMovieRecord.merge(records, into: context) { done, total in
                importProgress = (done: done, total: total)
            }
            importProgress = nil
            importSummary = summary
        }
    }

    /// Drives the create/edit sheet.
    private enum ListEditor: Identifiable {
        case create(addMovie: Movie?)
        case edit(MediaList)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let list): return list.uuid.uuidString
            }
        }

        var list: MediaList? {
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

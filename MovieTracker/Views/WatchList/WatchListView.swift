//
//  WatchListView.swift
//  MovieTracker
//
//  The user's movie lists, backed by SwiftData (+ CloudKit). The navigation
//  title is a menu that switches between lists and offers New/Edit List actions.
//  Two built-in lists always exist (To Watch, Watched); the user can add custom
//  ones. A sort menu flips ascending/descending and — on Watched — chooses
//  release date vs. date watched. Swipe actions move or remove entries.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct WatchListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\MovieList.sortOrder), SortDescriptor(\MovieList.createdAt)])
    private var lists: [MovieList]

    @State private var selectedListUUID: UUID?
    @State private var editor: ListEditor?

    /// Inline text used to narrow the current list down to matching titles.
    @State private var filterText = ""

    // Sort direction is remembered per list (keyed by UUID in UserDefaults):
    // Watched defaults to descending, every other list to ascending.
    @State private var sortAscending = true
    @AppStorage("watchedSortKey") private var watchedSortKey: WatchedSortKey = .releaseDate

    // Backup import/export. The export document is built on demand from the
    // current library; import/error results drive their own result alerts.
    @State private var exportDocument: WatchDataDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importSummary: ImportSummary?
    @State private var transferError: String?
    /// Progress of an in-flight CSV import (fetched, total); nil when idle.
    @State private var importProgress: (done: Int, total: Int)?

    /// Presents the Edit Lists modal (reorder/delete/edit custom lists).
    @State private var showListManager = false

    /// The list of month/year sections for the selected list. Extracted from
    /// `body` to keep the modifier chain type-checkable.
    private var listContent: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                        MovieListRow(
                            movie: movie(from: entry),
                            subtitle: subtitle(for: entry),
                            showsSubtitle: showsRowSubtitle,
                            duration: duration(for: entry),
                            rating: rating(for: entry),
                            ratingTint: activeListColor,
                            lists: lists,
                            context: context,
                            leadingActions: { leadingAction(for: entry) },
                            trailingActions: {
                                Button(role: .destructive) {
                                    WatchListStore.delete(entry, in: context)
                                } label: {
                                    Image(systemName: "trash")
                                        .tint(.red)
                                }
                            }
                        )
                        .listRowSeparator(index == section.entries.count - 1 ? .hidden : .automatic, edges: .bottom)
                    }
                } header: {
                    Text(section.title)
                        .foregroundStyle(activeListColor)
                }
            }
        }
    }

    var body: some View {
        listContent
        .listStyle(.plain)
        // Accent the nav-bar controls (title menu, sort) with the active list color.
        .tint(activeListColor)
        .navigationTitle(selectedList?.name ?? "Lists")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            // Title switcher rendered ourselves so the list name can carry the
            // list's color (the system navigation title can't be tinted).
            ToolbarItem(placement: .principal) {
                Menu {
                    titleMenu
                } label: {
                    HStack(spacing: 5) {
                        Text(selectedList?.name ?? "Lists")
                            .font(.headline)
                            .foregroundStyle(activeListColor)
                        // Mimic the system title-menu chevron: a small glyph in a
                        // subtle filled circle.
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(5)
                            .background(Color(.tertiarySystemFill), in: Circle())
                            // The system title-menu chevron sits a hair below the
                            // title's optical center.
                            .offset(y: 1)
                    }
                }
                .tint(.primary)
            }
            ToolbarItem(placement: .topBarLeading) {
                listActionsMenu
                    .tint(activeListColor)
            }
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
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
        .onAppear {
            WatchListStore.ensureDefaultLists(in: context)
            // The selection lives only in @State — it survives tab switches this
            // session but resets to the Watch List on a fresh launch.
            if selectedListUUID == nil {
                selectedListUUID = WatchListStore.list(kind: .toWatch, in: context)?.uuid
            }
        }
        .onChange(of: selectedListUUID) { _, _ in
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

    /// Loads the stored sort direction for the current list, falling back to the
    /// per-kind default (Watched descending, all others ascending) when unset.
    private func loadSort() {
        guard let list = selectedList else { return }
        if let stored = UserDefaults.standard.object(forKey: Self.sortKey(for: list)) as? Bool {
            sortAscending = stored
        } else {
            // Watched and Viewed read best newest-first; everything else oldest-first.
            sortAscending = list.kind != .watched && list.kind != .viewed
        }
    }

    // MARK: - Title menu

    /// The navigation-title menu is now just the list switcher — the two built-in
    /// lists up top and any custom lists below. Creating/editing/importing lives
    /// in the leading toolbar buttons instead.
    @ViewBuilder
    private var titleMenu: some View {
        Picker("List", selection: $selectedListUUID) {
            ForEach(topLists) { list in
                Label(list.name, systemImage: ListSymbol.outline(list.symbol)).tag(Optional(list.uuid))
            }
        }

        if !customLists.isEmpty {
            Divider()
            Picker("Custom List", selection: $selectedListUUID) {
                ForEach(customLists) { list in
                    Label {
                        Text(list.name)
                    } icon: {
                        // Emoji and the flip-prone smiley need a prebuilt image;
                        // ordinary symbols render fine via `systemName`.
                        if let image = ListSymbol.menuImage(list.symbol) {
                            Image(uiImage: image)
                        } else {
                            Image(systemName: ListSymbol.outline(list.symbol))
                                .foregroundStyle(list.color)
                        }
                    }
                    .tag(Optional(list.uuid))
                }
            }
        }

        // The Viewed history always sits below the custom lists.
        if let viewed = viewedList {
            Divider()
            Picker("Viewed", selection: $selectedListUUID) {
                Label(viewed.name, systemImage: ListSymbol.outline(viewed.symbol))
                    .tag(Optional(viewed.uuid))
            }
        }
    }

    // MARK: - List actions menu

    /// The leading ellipsis menu: create or manage lists, then import/export the
    /// whole library.
    private var listActionsMenu: some View {
        Menu {
            Button {
                editor = .create(addMovie: nil)
            } label: {
                Label("New List", systemImage: "plus")
            }

            if !customLists.isEmpty {
                Button {
                    showListManager = true
                } label: {
                    Label("Edit Lists", systemImage: "pencil")
                }
            }

            // Clearing only applies to the rotating Viewed history.
            if let list = selectedList, list.kind == .viewed, !(list.entries ?? []).isEmpty {
                Divider()

                Button(role: .destructive) {
                    WatchListStore.clear(list, in: context)
                } label: {
                    Label("Clear Viewed", systemImage: "trash")
                }
                // Override the menu's accent tint so the trash icon reads red too.
                .tint(.red)
            }

            Divider()

            Button {
                showImporter = true
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }

            Button {
                prepareExport()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }

            // Non-selectable version footer.
            Section {
                Text(appInfo)
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
    }

    private var appInfo: String {
        var appInfo: String = ""

        if let releaseVersionNumber = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appInfo.append(releaseVersionNumber)
        }

        if let buildVersionNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            if appInfo.isEmpty {
                appInfo.append(buildVersionNumber)
            } else {
                appInfo.append(" (\(buildVersionNumber))")
            }
        }

        return appInfo
    }

    // MARK: - Backup import/export

    /// A dated, filesystem-safe default name for the exported backup file.
    private var exportFilename: String {
        let stamp = Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "MovieTracker Backup \(stamp)"
    }

    /// Snapshots the whole library and presents the system export sheet.
    private func prepareExport() {
        exportDocument = WatchDataDocument(archive: WatchListStore.exportArchive(from: context))
        showExporter = true
    }

    /// Reads the chosen file and merges it, routing to the JSON backup or CSV
    /// (TodoMovies) importer by file type, then surfaces the result (or an error).
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

    /// Merges the app's own JSON backup synchronously.
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

    /// Parses a TodoMovies CSV export, then merges it while fetching each movie's
    /// details from TMDB. The file's read upfront; the network work runs in a
    /// task behind the progress overlay.
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

    // MARK: - Sorting menu

    private var sortMenu: some View {
        Menu {
            Picker("Order", selection: $sortAscending) {
                Text("Ascending").tag(true)
                Text("Descending").tag(false)
            }

            if selectedList?.tracksWatchedDate == true {
                Picker("Sort By", selection: $watchedSortKey) {
                    Text(WatchedSortKey.releaseDate.title).tag(WatchedSortKey.releaseDate)
                    Text(WatchedSortKey.dateWatched.title).tag(WatchedSortKey.dateWatched)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    // MARK: - Selection

    private var selectedList: MovieList? {
        if let id = selectedListUUID, let match = lists.first(where: { $0.uuid == id }) {
            return match
        }
        return lists.first { $0.kind == .toWatch } ?? lists.first
    }

    /// The two built-in lists shown above custom lists (To Watch, Watched).
    private var topLists: [MovieList] { lists.filter { $0.kind == .toWatch || $0.kind == .watched } }

    /// User-created lists.
    private var customLists: [MovieList] { lists.filter { $0.kind == .custom } }

    /// The built-in Viewed history, shown below the custom lists.
    private var viewedList: MovieList? { lists.first { $0.kind == .viewed } }

    /// The accent color for a list — each list's own tint (built-ins carry fixed
    /// brand colors, custom lists their chosen palette color).
    private func listColor(for list: MovieList) -> Color {
        list.color
    }

    /// Accent color for the currently selected list, used to theme the screen.
    private var activeListColor: Color {
        selectedList.map(listColor) ?? .appAccent
    }

    private var watchList: MovieList? { lists.first { $0.kind == .toWatch } }
    private var watchedList: MovieList? { lists.first { $0.kind == .watched } }

    private func select(_ list: MovieList?) {
        selectedListUUID = list?.uuid
    }

    // MARK: - Data

    /// A month/year group of entries, e.g. "May 2025".
    private struct MonthSection: Identifiable {
        let id: DateComponents
        let title: String
        let entries: [WatchListEntry]
    }

    /// Entries for the selected list, grouped into month/year sections and
    /// ordered (both sections and rows within them) per the ascending toggle.
    private var sections: [MonthSection] {
        let allEntries = selectedList?.entries ?? []
        let entries = filterText.isEmpty
            ? allEntries
            : allEntries.filter { $0.title.localizedCaseInsensitiveContains(filterText) }

        let grouped = Dictionary(grouping: entries) { entry -> DateComponents in
            Calendar.current.dateComponents([.year, .month], from: sortValue(for: entry))
        }

        let sortedKeys = grouped.keys.sorted { a, b in
            (a.year ?? 0, a.month ?? 0) < (b.year ?? 0, b.month ?? 0)
        }
        let orderedKeys = sortAscending ? sortedKeys : sortedKeys.reversed()

        return orderedKeys.map { key in
            let rows = (grouped[key] ?? []).sorted { sortValue(for: $0) < sortValue(for: $1) }
            let ordered = sortAscending ? rows : rows.reversed()
            let title = Calendar.current.date(from: key)
                .map { DateFormatter.sectionHeader.string(from: $0) } ?? "Unknown"
            return MonthSection(id: key, title: title, entries: Array(ordered))
        }
    }

    /// The date the selected list orders and groups by. Missing dates sort last
    /// in ascending order (they become `.distantFuture`).
    private func sortValue(for entry: WatchListEntry) -> Date {
        // Viewed orders and groups by when the movie was browsed.
        if selectedList?.kind == .viewed {
            return entry.dateAdded
        }
        if selectedList?.tracksWatchedDate == true, watchedSortKey == .dateWatched {
            return entry.dateWatched ?? .distantFuture
        }
        return entry.releaseDate ?? .distantFuture
    }

    private func emptyMessage(for list: MovieList) -> String {
        switch list.kind {
        case .toWatch: return "Movies you want to watch will appear here."
        case .watched: return "Movies you have watched will appear here."
        case .viewed: return "Movies you browse will appear here."
        case .custom: return "Movies you add to “\(list.name)” will appear here."
        }
    }

    // MARK: - Swipe actions

    /// Leading swipe: on Watched, send the movie back to the Watch List; on any
    /// other list, mark it Watched. Uses the same buttons as Search results.
    @ViewBuilder
    private func leadingAction(for entry: WatchListEntry) -> some View {
        let movie = movie(from: entry)
        if selectedList?.kind == .watched {
            WatchListSwipeButton(movie: movie, watchList: watchList, context: context)
        } else {
            WatchedSwipeButton(movie: movie, watchedList: watchedList, context: context)
        }
    }

    /// The Watched list always labels each row with the date the movie was watched;
    /// every other list lets the row fall back to the movie's release date.
    private func subtitle(for entry: WatchListEntry) -> String? {
        guard selectedList?.tracksWatchedDate == true else { return nil }
        return entry.dateWatched.map { "Watched \($0.toString())" }
    }

    /// The personal rating to show on a row, if the movie has been watched. Watched
    /// rows read their own entry; custom-list rows look the movie up on the Watched
    /// list so a rating still shows once it's been seen. Other lists show none.
    private func rating(for entry: WatchListEntry) -> Double? {
        switch selectedList?.kind {
        case .watched:
            return entry.userRating
        case .custom:
            guard let watchedList else { return nil }
            return WatchListStore.rating(for: entry.movieID, in: watchedList)
        default:
            return nil
        }
    }

    /// The runtime line ("2 hr 8 min") shown on To Watch rows, formatted like the
    /// movie detail page. Only the To Watch list surfaces it; nil elsewhere or when
    /// the entry has no stored runtime.
    private func duration(for entry: WatchListEntry) -> String? {
        guard selectedList?.kind == .toWatch else { return nil }
        return movie(from: entry).duration
    }

    /// Viewed is a browse history where the release date only adds noise, so its
    /// rows hide the subtitle. Other lists show it (or their own override).
    private var showsRowSubtitle: Bool {
        selectedList?.kind != .viewed
    }

    /// Rebuilds a Movie snapshot from an entry so moves preserve poster/date.
    private func movie(from entry: WatchListEntry) -> Movie {
        let movie = Movie(id: entry.movieID, title: entry.title)
        movie.poster = entry.posterPath
        movie.releaseDate = entry.releaseDate
        movie.runtime = entry.runtime
        return movie
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

/// The file exporter, importer, and their result alerts, split out of
/// `WatchListView.body` so the main modifier chain stays type-checkable.
private struct BackupTransferModifier: ViewModifier {
    @Binding var showExporter: Bool
    @Binding var showImporter: Bool
    let exportDocument: WatchDataDocument?
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

/// A blocking progress card shown while a CSV import fetches movie details from
/// TMDB. Determinate so the user can gauge how far a large library has to go.
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

#Preview {
    NavigationStack {
        WatchListView()
            .movieTrackerDestinations()
    }
    .modelContainer(previewModelContainer)
    .preferredColorScheme(.dark)
}

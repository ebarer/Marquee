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

struct WatchListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\MovieList.sortOrder), SortDescriptor(\MovieList.createdAt)])
    private var lists: [MovieList]

    @State private var selectedListUUID: UUID?
    @State private var editor: ListEditor?

    /// Inline text used to narrow the current list down to matching titles.
    @State private var filterText = ""

    @AppStorage("watchListSortAscending") private var sortAscending = true
    @AppStorage("watchedSortKey") private var watchedSortKey: WatchedSortKey = .releaseDate

    // Remembers the last-viewed list and when it was last seen, so re-entering
    // the tab restores it — unless it's gone stale (defaults back to To Watch).
    @AppStorage("watchListLastListUUID") private var lastListUUID = ""
    @AppStorage("watchListLastViewedAt") private var lastViewedAt = 0.0

    /// After this long away, the list resets to To Watch on the next visit.
    private static let staleInterval: TimeInterval = 3 * 60 * 60

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                        MovieListRow(
                            movie: movie(from: entry),
                            subtitle: subtitle(for: entry),
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
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(selectedList?.name ?? "Lists")
        .toolbarTitleDisplayMode(.inline)
        .toolbarTitleMenu {
            titleMenu
                .tint(.primary)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
        .searchable(text: $filterText, prompt: "Filter \(selectedList?.name ?? "list")")
        .overlay {
            if let list = selectedList, (list.entries ?? []).isEmpty {
                ContentUnavailableView {
                    Label(list.name, systemImage: list.symbol)
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
        .onAppear {
            WatchListStore.ensureDefaultLists(in: context)
            restoreSelection()
        }
        .onChange(of: selectedListUUID) { _, _ in
            recordVisit()
        }
    }

    // MARK: - Title menu

    @ViewBuilder
    private var titleMenu: some View {
        Picker("List", selection: $selectedListUUID) {
            ForEach(defaultLists) { list in
                Label(list.name, systemImage: list.symbol).tag(Optional(list.uuid))
            }
        }

        if !customLists.isEmpty {
            Divider()
            Picker("Custom List", selection: $selectedListUUID) {
                ForEach(customLists) { list in
                    Label(list.name, systemImage: list.symbol).tag(Optional(list.uuid))
                }
            }
        }

        Divider()

        Button {
            editor = .create(addMovie: nil)
        } label: {
            Label("New List…", systemImage: "plus")
        }

        if let list = selectedList, list.isEditable {
            Button {
                editor = .edit(list)
            } label: {
                Label("Edit List…", systemImage: "pencil")
            }
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

    /// The two built-in lists (To Watch, Watched), in order.
    private var defaultLists: [MovieList] { lists.filter { $0.kind != .custom } }

    /// User-created lists.
    private var customLists: [MovieList] { lists.filter { $0.kind == .custom } }

    private var watchList: MovieList? { lists.first { $0.kind == .toWatch } }
    private var watchedList: MovieList? { lists.first { $0.kind == .watched } }

    private var showsWatchedDate: Bool {
        selectedList?.tracksWatchedDate == true && watchedSortKey == .dateWatched
    }

    private func select(_ list: MovieList?) {
        selectedListUUID = list?.uuid
    }

    /// Restores the last-viewed list, resetting to To Watch if it's been too long.
    private func restoreSelection() {
        let elapsed = Date.timeIntervalSinceReferenceDate - lastViewedAt
        if elapsed > Self.staleInterval {
            select(lists.first { $0.kind == .toWatch })
        } else if let stored = UUID(uuidString: lastListUUID),
                  lists.contains(where: { $0.uuid == stored }) {
            selectedListUUID = stored
        } else {
            select(lists.first { $0.kind == .toWatch })
        }
        recordVisit()
    }

    private func recordVisit() {
        lastListUUID = selectedListUUID?.uuidString ?? ""
        lastViewedAt = Date.timeIntervalSinceReferenceDate
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
        if selectedList?.tracksWatchedDate == true, watchedSortKey == .dateWatched {
            return entry.dateWatched ?? .distantFuture
        }
        return entry.releaseDate ?? .distantFuture
    }

    private func emptyMessage(for list: MovieList) -> String {
        switch list.kind {
        case .toWatch: return "Movies you want to watch will appear here."
        case .watched: return "Movies you have watched will appear here."
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

    /// When the list sorts by date watched, surface that date; otherwise let the
    /// row fall back to the movie's release date.
    private func subtitle(for entry: WatchListEntry) -> String? {
        guard showsWatchedDate else { return nil }
        return entry.dateWatched.map { "Watched \($0.toString())" }
    }

    /// Rebuilds a Movie snapshot from an entry so moves preserve poster/date.
    private func movie(from entry: WatchListEntry) -> Movie {
        let movie = Movie(id: entry.movieID, title: entry.title)
        movie.poster = entry.posterPath
        movie.releaseDate = entry.releaseDate
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

#Preview {
    NavigationStack {
        WatchListView()
            .movieTrackerDestinations()
    }
    .modelContainer(previewModelContainer)
    .preferredColorScheme(.dark)
}

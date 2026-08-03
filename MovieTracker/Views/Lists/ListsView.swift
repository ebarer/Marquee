//
//  ListsView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData
import CoreData

struct ListsView: View {
    @Environment(MediaStore.self) private var store: MediaStore?
    /// Present only when running inside the app (absent in previews).
    @Environment(CloudSyncMonitor.self) private var syncMonitor: CloudSyncMonitor?
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var allLists: [MediaList]

    /// Canonical, display-ready lists. `@Query` drives reactivity; the store owns the
    /// decision of which duplicate copies to collapse.
    private var lists: [MediaList] {
        store?.canonicalLists(allLists) ?? allLists.filter { !$0.isDeduplicated }
    }

    /// The current view; nil until the Watch List is chosen on appear.
    @State private var selection: ListSelection?
    @State private var editor: ListEditor?

    @State private var sections: [SectionSnapshot] = []
    /// The input the current `sections` were built for. Used to suppress the empty
    /// state during the async rebuild after a selection change (so it doesn't flash).
    @State private var loadedInput: SectionsInput?
    @State private var builder: SectionBuilder?
    /// Bumped on any store change so the sections rebuild even when a count is
    /// unchanged (e.g. a watched-date edit).
    @State private var dataVersion = 0
    @State private var filterText = ""

    @AppStorage("watchedListAscending") private var watchedAscending = false
    @AppStorage("viewedListAscending") private var viewedAscending = false
    @AppStorage("watchedSortKey") private var watchedSortKey: WatchedSortKey = .dateWatched

    @State private var showListManager = false

    var body: some View {
        ListRows(sections: sections, selection: resolvedSelection, lists: lists,
                      listColor: activeColor)
        .listStyle(.plain)
        .tint(activeColor)
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Menu {
                    ListTitleMenu(selection: selectionBinding, watchList: watchList,
                                       customLists: customLists)
                } label: {
                    ListTitleLabel(name: title, color: activeColor, count: movieCount)
                }
                .tint(.primary)
            }
            ToolbarItemGroup(placement: .topBarLeading) {
                Button {
                    editor = .create(addMovie: nil)
                } label: {
                    Label("New List", systemImage: "plus")
                }
                .tint(activeColor)
                // While iCloud is syncing, the manage button is briefly replaced by a
                // spinner in place rather than adding a separate trailing indicator.
                if syncMonitor?.isSyncing == true {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(activeColor)
                        .accessibilityLabel("Syncing with iCloud")
                } else {
                    Button {
                        showListManager = true
                    } label: {
                        Label("Manage Lists", systemImage: "list.bullet")
                    }
                    .tint(activeColor)
                }
            }
            if resolvedSelection == .viewed {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        store?.clearViewed()
                    } label: {
                        Label("Clear Viewed", systemImage: "trash")
                    }
                    .tint(activeColor)
                    .disabled(movieCount == 0)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    ListSortMenu(ascending: ascendingBinding, watchedSortKey: $watchedSortKey,
                                      showsWatchedSortKey: resolvedSelection == .watched)
                        .tint(activeColor)
                }
            }
        }
        .searchable(text: $filterText, prompt: "Search \(title)")
        .overlay {
            // Only once the rebuild for the current input has landed, so the empty
            // state doesn't flash while switching lists.
            if sections.isEmpty, loadedInput == sectionsInput {
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
                        if let movie = mode.movieToAdd { store?.add(movie, to: newList) }
                        selection = .list(newList.uuid)
                    },
                    onDeleted: { selection = watchList.map { .list($0.uuid) } }
                )
            }
        }
        .sheet(isPresented: $showListManager) {
            ListManagerView()
        }
        .task(id: sectionsInput) { await rebuildSections() }
        // A local save (e.g. a watched-date edit) that doesn't change a count still
        // needs a rebuild. Scoped to the main context.
        .task {
            let mainContext = store?.container.mainContext
            for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave, object: mainContext) {
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
        case .watched: return store?.watchedCount ?? 0
        case .viewed: return store?.viewedCount ?? 0
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
        guard let source = sectionSource, let store else {
            sections = []
            loadedInput = sectionsInput
            return
        }
        let builder = builder ?? SectionBuilder(modelContainer: store.container)
        if self.builder == nil { self.builder = builder }

        let result = await builder.build(source: source, ascending: currentAscending, filter: filterText)
        guard !Task.isCancelled else { return }
        sections = result
        loadedInput = sectionsInput
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
        ListsView()
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(MediaStore(previewModelContainer.mainContext))
    .environment(CloudSyncMonitor(isSyncing: false))
    .preferredColorScheme(.dark)
}

#Preview("Syncing") {
    NavigationStack {
        ListsView()
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(MediaStore(previewModelContainer.mainContext))
    .environment(CloudSyncMonitor(isSyncing: true))
    .preferredColorScheme(.dark)
}

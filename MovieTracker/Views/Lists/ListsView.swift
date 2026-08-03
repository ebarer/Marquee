//
//  ListsView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData
import CoreData

struct ListsView: View {
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
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

    /// Builds and holds the month/year section snapshots off the main actor.
    @State private var sectionsModel = ListSectionsModel()
    /// Bumped on any store change so the sections rebuild even when a count is
    /// unchanged (e.g. a watched-date edit).
    @State private var dataVersion = 0
    @State private var filterText = ""

    @AppStorage("watchedListAscending") private var watchedAscending = false
    @AppStorage("viewedListAscending") private var viewedAscending = false
    @AppStorage("watchedSortKey") private var watchedSortKey: WatchedSortKey = .dateWatched

    @State private var showListManager = false

    var body: some View {
        ListRows(sections: sectionsModel.sections, selection: resolvedSelection, lists: lists,
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
            if sectionsModel.sections.isEmpty, sectionsModel.loadedInput == sectionsInput {
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
        .task(id: sectionsInput) { await sectionsModel.rebuild(for: sectionsInput, store: store) }
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
        .onChange(of: selection) { _, _ in sectionsModel.clear() }
    }

    // MARK: - Selection

    private var resolvedSelection: ListSelection { selection ?? defaultSelection }
    private var defaultSelection: ListSelection { watchList.map { .list($0.uuid) } ?? .watched }

    private var selectionBinding: Binding<ListSelection> {
        Binding(get: { resolvedSelection }, set: { selection = $0 })
    }

    private var watchList: MediaList? { lists.first { $0.isWatchList } }
    private var customLists: [MediaList] { lists.filter { !$0.isWatchList } }

    private func selectDefaultIfNeeded() {
        guard selection == nil, let watch = watchList else { return }
        selection = .list(watch.uuid)
    }

    // MARK: - Derived per-selection

    /// The current view resolved to its identity + contents; the source of the
    /// title, color, count, empty state, and section source below.
    private var destination: ListDestination { .resolve(resolvedSelection, lists: lists) }

    private var title: String { destination.name }
    private var activeColor: Color { destination.color }
    private var movieCount: Int { destination.movieCount(using: store) }
    private var sectionSource: SectionSource? {
        destination.sectionSource(watchedByDate: watchedSortKey == .dateWatched)
    }

    private var currentAscending: Bool {
        switch resolvedSelection {
        case .list: return destination.list?.sortAscending ?? true
        case .watched: return watchedAscending
        case .viewed: return viewedAscending
        }
    }

    private var ascendingBinding: Binding<Bool> {
        Binding(get: { currentAscending }, set: { setAscending($0) })
    }

    private func setAscending(_ value: Bool) {
        switch resolvedSelection {
        case .list: store?.perform { destination.list?.sortAscending = value }
        case .watched: watchedAscending = value
        case .viewed: viewedAscending = value
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text(destination.name)
            } icon: {
                ListIcon(symbol: destination.symbol, color: destination.color, size: 64)
            }
        } description: {
            Text(destination.emptyDescription)
        }
    }

    // MARK: - Data

    /// The current build input; `sectionSource` already encodes the selection and
    /// watched-sort key, `dataVersion` forces a rebuild after a silent edit.
    private var sectionsInput: ListSectionsModel.Input {
        ListSectionsModel.Input(source: sectionSource, count: movieCount,
                                ascending: currentAscending, filter: filterText, version: dataVersion)
    }
}

#Preview("Idle") {
    NavigationStack {
        ListsView()
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .environment(CloudSyncMonitor(isSyncing: false))
    .preferredColorScheme(.dark)
}

#Preview("Syncing") {
    NavigationStack {
        ListsView()
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .environment(CloudSyncMonitor(isSyncing: true))
    .preferredColorScheme(.dark)
}

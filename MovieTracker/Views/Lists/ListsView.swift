//
//  ListsView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The compact (iPhone) Lists host: owns the current selection, the title-bar list
/// switcher, and the New List / Manage Lists chrome. The rows themselves are drawn
/// by `ListContentView`, which the iPad sidebar reuses directly.
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

    /// Bumped by the root tab bar when the already-selected Lists tab is tapped
    /// again; each change snaps the selection back to the Watch List.
    var resetToken = 0

    /// The current view; nil until the Watch List is chosen on appear.
    @State private var selection: ListSelection?
    @State private var editor: ListEditor?
    @State private var showListManager = false

    var body: some View {
        ListContentView(selection: resolvedSelection)
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
            .onAppear { selectDefaultIfNeeded() }
            .onChange(of: lists.count) { _, _ in selectDefaultIfNeeded() }
            .onChange(of: resetToken) { _, _ in
                if let watch = watchList { selection = .list(watch.uuid) }
            }
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

    // MARK: - Title chrome

    /// Resolves the current selection to the name / color / count shown in the
    /// title menu label. (The rows and their toolbar live in `ListContentView`.)
    private var destination: ListDestination { .resolve(resolvedSelection, lists: lists) }
    private var title: String { destination.name }
    private var activeColor: Color { destination.color }
    private var movieCount: Int { destination.movieCount(using: store) }
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

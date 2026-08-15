//
//  ListsView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The compact (iPhone) Lists host: owns selection and chrome; rows come from `ListContentView`.
struct ListsView: View {
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Environment(CloudSyncMonitor.self) private var syncMonitor: CloudSyncMonitor?
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var allLists: [MediaList]

    private var lists: [MediaList] {
        store?.canonicalLists(allLists) ?? allLists.filter { !$0.isDeduplicated }
    }

    var resetToken = 0

    @State private var selection: ListSelection?
    @State private var showListManager = false

    /// The visible filtered count
    @State private var visibleCount: Int?

    var body: some View {
        ListContentView(selection: resolvedSelection)
            .onListVisibleCountChange { visibleCount = $0 }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Menu {
                        ListTitleMenu(selection: selectionBinding, watchList: watchList,
                                           customLists: customLists)
                    } label: {
                        ListTitleLabel(name: title, color: activeColor,
                                       count: mediaCount, visible: visibleCount)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showListManager = true
                    } label: {
                        Label("Manage Lists", systemImage: "list.bullet")
                    }
                    .tint(activeColor)
                }
                if syncMonitor?.isSyncing == true {
                    ToolbarItem(placement: .topBarLeading) {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(activeColor)
                            .accessibilityLabel("Syncing with iCloud")
                    }
                    .sharedBackgroundVisibility(.hidden)
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

    private var destination: ListDestination { .resolve(resolvedSelection, lists: lists) }
    private var title: String { destination.name }
    private var activeColor: Color { destination.color }
    private var mediaCount: Int { destination.mediaCount(using: store) }
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

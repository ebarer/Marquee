//
//  SidebarColumn.swift
//  MovieTracker
//
//  The iPad sidebar: Discover collections + every list, plus the New List / Manage
//  Lists chrome moved off the Lists screen.
//

import SwiftUI
import SwiftData

struct SidebarColumn: View {
    @Binding var selection: SidebarItem?

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Environment(CloudSyncMonitor.self) private var syncMonitor: CloudSyncMonitor?
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var allLists: [MediaList]

    private var lists: [MediaList] {
        store?.canonicalLists(allLists) ?? allLists.filter { !$0.isDeduplicated }
    }
    private var watchList: MediaList? { lists.first { $0.isWatchList } }
    private var customLists: [MediaList] { lists.filter { !$0.isWatchList } }

    @State private var editor: ListEditor?
    @State private var showListManager = false

    var body: some View {
        List(selection: $selection) {
            Section("Discover") {
                ForEach(FeaturedCollection.allCases) { collection in
                    Label(collection.title, systemImage: collection.symbol)
                        .tag(SidebarItem.collection(collection))
                }
            }

            Section("Lists") {
                if let watchList {
                    listRow(watchList)
                }
                derivedRow(name: "Watched", symbol: "checkmark.rectangle.stack",
                           color: ListDestination.watchedColor, tag: .list(.watched))
                ForEach(customLists) { listRow($0) }
                derivedRow(name: "Viewed", symbol: "clock.arrow.circlepath",
                           color: ListDestination.viewedColor, tag: .list(.viewed))
            }
        }
        .navigationTitle("Marquee")
        .toolbar { toolbar }
        .sheet(item: $editor) { mode in editorSheet(mode) }
        .sheet(isPresented: $showListManager) { ListManagerView() }
    }

    // MARK: - Rows

    /// A real `MediaList` (Watch List or custom), matching the title menu's icon.
    private func listRow(_ list: MediaList) -> some View {
        Label {
            Text(list.name)
        } icon: {
            if let image = ListSymbol.menuImage(list.symbol) {
                Image(uiImage: image)
            } else {
                Image(systemName: ListSymbol.outline(list.symbol))
                    .foregroundStyle(list.color)
            }
        }
        .tag(SidebarItem.list(.list(list.uuid)))
    }

    /// A derived view (Watched / Viewed) with a fixed symbol + tint.
    private func derivedRow(name: String, symbol: String, color: Color,
                            tag: SidebarItem) -> some View {
        Label {
            Text(name)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(color)
        }
        .tag(tag)
    }

    // MARK: - Chrome

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                editor = .create(addMovie: nil)
            } label: {
                Label("New List", systemImage: "plus")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            // While iCloud is syncing, swap the manage button for a spinner in place.
            if syncMonitor?.isSyncing == true {
                ProgressView()
                    .controlSize(.regular)
                    .accessibilityLabel("Syncing with iCloud")
            } else {
                Button {
                    showListManager = true
                } label: {
                    Label("Manage Lists", systemImage: "list.bullet")
                }
            }
        }
    }

    private func editorSheet(_ mode: ListEditor) -> some View {
        NavigationStack {
            ListEditorView(
                existing: mode.list,
                nextSortOrder: (customLists.map(\.sortOrder).max() ?? 0) + 1,
                onSaved: { newList in
                    if let movie = mode.movieToAdd { store?.add(movie, to: newList) }
                    selection = .list(.list(newList.uuid))
                },
                onDeleted: { selection = watchList.map { .list(.list($0.uuid)) } }
            )
        }
    }
}

#Preview {
    @Previewable @State var selection: SidebarItem? = .collection(.popular)
    NavigationStack {
        SidebarColumn(selection: $selection)
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .environment(CloudSyncMonitor(isSyncing: false))
    .preferredColorScheme(.dark)
}

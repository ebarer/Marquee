//
//  SidebarColumn.swift
//  MovieTracker
//
//  The iPad sidebar: Discover collections + every list (with counts), plus the
//  Manage Lists entry point. New lists are created from within Manage Lists.
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

    // The Watched / Viewed counts come from a fetch, not an observed property, so
    // touch `revision` to re-read them after any write (marking a movie watched
    // otherwise left these badges stale until an unrelated change refreshed the row).
    private var watchedCount: Int {
        _ = store?.revision
        return store?.watchedCount ?? 0
    }
    private var viewedCount: Int {
        _ = store?.revision
        return store?.viewedCount ?? 0
    }

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
                // A ForEach (not a bare `if let`) so the row carries its selection
                // tag into `List(selection:)`; a conditional row silently loses it.
                ForEach(watchList.map { [$0] } ?? []) { listRow($0) }
                derivedRow(name: "Watched", symbol: "checkmark.rectangle.stack",
                           color: ListDestination.watchedColor, tag: .list(.watched),
                           count: watchedCount)
                ForEach(customLists) { listRow($0) }
                derivedRow(name: "Viewed", symbol: "clock.arrow.circlepath",
                           color: ListDestination.viewedColor, tag: .list(.viewed),
                           count: viewedCount)
            }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $showListManager) { ListManagerView() }
    }

    // MARK: - Rows

    /// A real `MediaList` (Watch List or custom). When selected, the symbol/text go
    /// white to read on the highlight; otherwise the symbol keeps the list color.
    private func listRow(_ list: MediaList) -> some View {
        let tag = SidebarItem.list(.list(list.uuid))
        let selected = selection == tag
        return Label {
            Text(list.name)
                .foregroundStyle(selected ? Color.white : Color.primary)
        } icon: {
            if let image = ListSymbol.menuImage(list.symbol) {
                Image(uiImage: image)
            } else {
                Image(systemName: ListSymbol.outline(list.symbol))
                    .foregroundStyle(selected ? Color.white : list.color)
            }
        }
        // `.tag` must be the outermost modifier or `List(selection:)` won't see it
        // (a trailing `.badge` shadows it — this is why the Watch List row was dead).
        .badge(list.entries?.count ?? 0)
        .tag(tag)
    }

    /// A derived view (Watched / Viewed) with a fixed symbol + tint and count.
    private func derivedRow(name: String, symbol: String, color: Color,
                            tag: SidebarItem, count: Int) -> some View {
        let selected = selection == tag
        return Label {
            Text(name)
                .foregroundStyle(selected ? Color.white : Color.primary)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(selected ? Color.white : color)
        }
        .badge(count)
        .tag(tag)
    }

    // MARK: - Chrome

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
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

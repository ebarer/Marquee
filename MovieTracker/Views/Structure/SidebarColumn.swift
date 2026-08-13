//
//  SidebarColumn.swift
//  MovieTracker
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

    // The Watched / Viewed counts come from a fetch, not an observed property, so touch
    // `revision` to re-read them after any write (else these badges stay stale).
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
                // A ForEach (not a bare `if let`) so the row carries its selection tag into
                // `List(selection:)`; a conditional row silently loses it.
                ForEach(watchList.map { [$0] } ?? []) { listRow($0) }
                derivedRow(name: "Watched", symbol: "checkmark.rectangle.stack",
                           color: ListDestination.watchedColor, tag: .list(.watched),
                           count: watchedCount)
            }

            if !customLists.isEmpty {
                Section {
                    ForEach(customLists) { listRow($0) }
                }
            }

            Section {
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

    private func listRow(_ list: MediaList) -> some View {
        let tag = SidebarItem.list(.list(list.uuid))
        let selected = selection == tag
        return SidebarRow(title: list.name, tag: tag, selected: selected,
                          badge: list.entries?.count ?? 0) {
            if let image = ListSymbol.menuImage(list.symbol) {
                Image(uiImage: image)
            } else {
                Image(systemName: ListSymbol.outline(list.symbol))
                    .foregroundStyle(selected ? Color.white : list.color)
            }
        }
    }

    private func derivedRow(name: String, symbol: String, color: Color,
                            tag: SidebarItem, count: Int) -> some View {
        let selected = selection == tag
        return SidebarRow(title: name, tag: tag, selected: selected, badge: count) {
            Image(systemName: symbol)
                .foregroundStyle(selected ? Color.white : color)
        }
    }

    // MARK: - Chrome

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showListManager = true
            } label: {
                Label("Manage Lists", systemImage: "list.bullet")
            }
        }
        if syncMonitor?.isSyncing == true {
            ToolbarItem(placement: .topBarLeading) {
                ProgressView()
                    .controlSize(.regular)
                    .accessibilityLabel("Syncing with iCloud")
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }
}

// A `.constant` binding, not `@Previewable @State`: the latter runs the view's `@Query` before
// `.modelContainer` attaches, crashing with "No eligible connection available".
#Preview {
    NavigationStack {
        SidebarColumn(selection: .constant(.collection(.popular)))
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .environment(CloudSyncMonitor(isSyncing: false))
    .preferredColorScheme(.dark)
}

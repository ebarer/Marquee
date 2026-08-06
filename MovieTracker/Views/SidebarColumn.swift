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
                           color: ListDestination.watchedColor, tag: .list(.watched),
                           count: store?.watchedCount ?? 0)
                ForEach(customLists) { listRow($0) }
                derivedRow(name: "Viewed", symbol: "clock.arrow.circlepath",
                           color: ListDestination.viewedColor, tag: .list(.viewed),
                           count: store?.viewedCount ?? 0)
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
        .tag(tag)
        .badge(list.entries?.count ?? 0)
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
        .tag(tag)
        .badge(count)
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

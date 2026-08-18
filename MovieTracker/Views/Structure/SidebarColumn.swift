//
//  SidebarColumn.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A row of the sidebar's Lists section, from a stored `MediaList` or derived (Watched, Viewed).
private struct ListRow: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let color: Color
    let tag: SidebarItem
    let count: Int
    let assetImage: UIImage?

    init(_ list: MediaList) {
        id = list.uuid.uuidString
        name = list.name
        symbol = ListSymbol.outline(list.symbol)
        color = list.color
        tag = .list(.list(list.uuid))
        count = list.entries?.count ?? 0
        assetImage = ListSymbol.menuImage(list.symbol)
    }

    init(name: String, symbol: String, color: Color, tag: SidebarItem, count: Int) {
        id = name
        self.name = name
        self.symbol = symbol
        self.color = color
        self.tag = tag
        self.count = count
        assetImage = nil
    }
}

struct SidebarColumn: View {
    @Binding var selection: SidebarItem?
    /// Called when the selected row is tapped again, whichever row it is.
    var onReselect: () -> Void = {}

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
    @State private var discoverExpanded = true
    @State private var listsExpanded = true

    /// A tap on the selected row writes the same value back rather than nothing, which is the
    /// only signal that it was tapped again.
    private var tappedSelection: Binding<SidebarItem?> {
        Binding {
            selection
        } set: { tapped in
            if let tapped, tapped == selection { onReselect() }
            selection = tapped
        }
    }

    var body: some View {
        List(selection: tappedSelection) {
            Section("Discover", isExpanded: $discoverExpanded) {
                ForEach(FeaturedCollection.allCases) { collectionRow($0) }
            }

            // Every list in one section, rendered by one ForEach: a second collapsible section
            // crashes the sidebar list's cell dequeue, and so does a second ForEach in here.
            Section("Lists", isExpanded: $listsExpanded) {
                ForEach(listRows) { listRow($0) }
            }
        }
        // `.sidebar` is what puts the disclosure control on the "Lists" header.
        .listStyle(.sidebar)
        // The selection pill draws in the tint, so it takes the selected list's own colour.
        .tint(selectionTint)
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $showListManager) { ListManagerView() }
    }

    private var selectionTint: Color {
        guard case .list(let listSelection) = selection else { return .appAccent }
        return ListDestination.resolve(listSelection, lists: lists).color
    }

    // MARK: - Rows

    private func collectionRow(_ collection: FeaturedCollection) -> some View {
        let selected = selection == .collection(collection)
        return Label {
            Text(collection.title)
        } icon: {
            // Pinned, because the list-wide tint below follows the selected list's colour and
            // would otherwise drag Discover along with it.
            collection.icon
                .foregroundStyle(selected ? Color.white : Color.appAccent)
        }
        .tag(SidebarItem.collection(collection))
    }

    /// The Lists section in canonical order: Watch List, Watched, custom lists, Viewed.
    private var listRows: [ListRow] {
        (watchList.map { [ListRow($0)] } ?? [])
        + [ListRow(name: "Watched", symbol: "checkmark.rectangle.stack",
                   color: ListDestination.watchedColor, tag: .list(.watched),
                   count: watchedCount)]
        + customLists.map(ListRow.init)
        + [ListRow(name: "Viewed", symbol: "clock.arrow.circlepath",
                   color: ListDestination.viewedColor, tag: .list(.viewed),
                   count: viewedCount)]
    }

    private func listRow(_ row: ListRow) -> some View {
        let selected = selection == row.tag
        return SidebarRow(title: row.name, tag: row.tag, selected: selected, badge: row.count) {
            if let image = row.assetImage {
                Image(uiImage: image)
            } else {
                Image(systemName: row.symbol)
                    .foregroundStyle(selected ? Color.white : row.color)
            }
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
#Preview("Discover selected") {
    NavigationStack {
        SidebarColumn(selection: .constant(.collection(.popularMovies)))
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .environment(CloudSyncMonitor(isSyncing: false))
    .preferredColorScheme(.dark)
}

// Watched is turquoise, so the sidebar tint is too: the Discover icons above must stay gold.
#Preview("List selected") {
    NavigationStack {
        SidebarColumn(selection: .constant(.list(.watched)))
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .environment(CloudSyncMonitor(isSyncing: false))
    .preferredColorScheme(.dark)
}

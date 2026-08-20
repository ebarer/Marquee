//
//  ListContentView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Rows, toolbar and filter for one `ListSelection`. A nil `externalFilter` means this view owns its search field.
struct ListContentView: View {
    let selection: ListSelection
    var externalFilter: String? = nil
    var sortPlacement: ToolbarItemPlacement = .topBarTrailing
    var startToken: Int = 0

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var allLists: [MediaList]

    private var lists: [MediaList] {
        store?.canonicalLists(allLists) ?? allLists.filter { !$0.isDeduplicated }
    }

    @State private var sectionsModel = ListSectionsModel()
    @State private var localFilter = ""

    @AppStorage("watchedListAscending") private var watchedAscending = false
    @AppStorage("viewedListAscending") private var viewedAscending = false
    @AppStorage("watchedSortKey") private var watchedSortKey: WatchedSortKey = .dateWatched
    @AppStorage("watchListFoldOlder") private var foldOlderMovies = true
    @AppStorage("watchListFoldOlderShows") private var foldOlderShows = false
    @AppStorage("listMediaTypeFilter") private var mediaFilter: MediaTypeFilter = .all

    private var filterText: String { externalFilter ?? localFilter }

    private var showsTable: Bool { externalFilter == nil }

    var body: some View {
        if showsTable {
            core.searchable(text: $localFilter, prompt: "Search \(title)")
        } else {
            core
        }
    }

    @ViewBuilder
    private var entries: some View {
        if showsTable {
            ListTable(sections: sectionsModel.sections, context: entryContext, lists: lists,
                      startToken: startToken)
                .equatable()
                .listStyle(.plain)
        } else {
            ListGrid(sections: sectionsModel.sections, context: entryContext, lists: lists)
        }
    }

    private var core: some View {
        entries
        .tint(activeColor)
        .pageTint(activeColor)
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            // The iPhone's host supplies its own title (the list switcher); this is the iPad,
            // where the bar would otherwise show a plain white name and no count.
            if !showsTable {
                ToolbarItem(placement: .title) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(activeColor)
                }
                ToolbarItem(placement: .subtitle) {
                    // Sized and greyed as `ListTitleLabel` does it on the phone.
                    countLabel
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if selection == .viewed {
                ToolbarItem(placement: sortPlacement) {
                    Button(role: .destructive) {
                        store?.clearViewed()
                    } label: {
                        Label("Clear Viewed", systemImage: "trash")
                    }
                    .tint(activeColor)
                    .disabled(mediaCount == 0)
                }
            } else {
                ToolbarItem(placement: sortPlacement) {
                    ListSortMenu(ascending: ascendingBinding,
                                 watchedSortKey: selection == .watched ? $watchedSortKey : nil,
                                 listSortKey: isRealList ? listSortKeyBinding : nil,
                                 listSortKeys: listSortKeys,
                                 foldOlderMovies: showsFoldToggle ? $foldOlderMovies : nil,
                                 foldOlderShows: showsFoldToggle ? $foldOlderShows : nil,
                                 mediaFilter: $mediaFilter,
                                 tint: activeColor)
                        .tint(activeColor)
                }
            }
        }
        .overlay {
            // Gate on loadedInput == sectionsInput so the empty state doesn't flash while switching lists.
            if sectionsModel.sections.isEmpty, sectionsModel.loadedInput == sectionsInput {
                if !filterText.isEmpty {
                    ContentUnavailableView.search(text: filterText)
                } else {
                    emptyState
                }
            }
        }
        .task(id: sectionsInput) { await sectionsModel.rebuild(for: sectionsInput, store: store) }
        .onChange(of: selection) { _, _ in sectionsModel.clear() }
        // The compact shell owns its navigation title, so it reads the count from here.
        .listVisibleCount(visibleCount)
    }

    private var visibleCount: Int {
        guard sectionsModel.loadedInput == sectionsInput else { return mediaCount }
        return sectionsModel.sections.reduce(0) { $0 + $1.entries.count }
    }

    private var countLabel: Text {
        visibleCount == mediaCount
            ? Text("^[\(mediaCount) Title](inflect: true)")
            : Text("\(visibleCount) of ^[\(mediaCount) Title](inflect: true)")
    }

    // MARK: - Derived per-selection

    private var destination: ListDestination { .resolve(selection, lists: lists) }

    private var entryContext: ListEntryContext {
        ListEntryContext(selection: selection, isWatchList: destination.list?.isWatchList == true,
                         watchListIDs: watchListIDs, listColor: activeColor,
                         caughtUpShowIDs: caughtUpShowIDs)
    }

    private var caughtUpShowIDs: Set<Int> {
        guard let store else { return [] }
        return Set(sectionsModel.sections.flatMap(\.entries)
            .filter { $0.mediaType == .tv && store.badges.isShowCaughtUp(showID: $0.tmdbID) }
            .map(\.tmdbID))
    }

    // Resolved here so the rows get a value and never query the store themselves.
    private var watchListIDs: Set<Int> {
        guard isCustomList else { return [] }
        let watchList = lists.first { $0.isWatchList }
        return Set((watchList?.entries ?? []).map(\.tmdbID))
    }

    private var isCustomList: Bool {
        if case .list = selection { return destination.list?.isWatchList == false }
        return false
    }

    private var title: String { destination.name }
    private var activeColor: Color { destination.color }
    private var mediaCount: Int { destination.mediaCount(using: store) }
    private var listRequest: ListRequest? {
        destination.listRequest(watchedSort: watchedSortKey,
                                listSort: currentListSortKey,
                                listFoldOlder: foldsOlder)
    }

    private var foldsOlder: OlderFold {
        var fold: OlderFold = []
        if foldOlderMovies { fold.insert(.movies) }
        if foldOlderShows { fold.insert(.shows) }
        return fold
    }

    private var isRealList: Bool {
        if case .list = selection { return true }
        return false
    }

    private var listSortKeys: [ListSortKey] {
        ListSortKey.options(isWatchList: destination.list?.isWatchList == true)
    }

    private var currentListSortKey: ListSortKey {
        let stored = destination.list?.sortKey ?? .releaseDate
        return listSortKeys.contains(stored) ? stored : .releaseDate
    }

    // Folding only produces an "Older" bucket for the Watch List sorted by release
    // date; under date-added the list is flat, so the toggle would be a no-op.
    private var showsFoldToggle: Bool {
        destination.list?.isWatchList == true && currentListSortKey == .releaseDate
    }

    private var listSortKeyBinding: Binding<ListSortKey> {
        Binding(get: { currentListSortKey },
                set: { value in store?.perform { destination.list?.sortKey = value } })
    }

    private var currentAscending: Bool {
        switch selection {
        case .list: return destination.list?.sortAscending ?? true
        case .watched: return watchedAscending
        case .viewed: return viewedAscending
        }
    }

    private var ascendingBinding: Binding<Bool> {
        Binding(get: { currentAscending }, set: { setAscending($0) })
    }

    private func setAscending(_ value: Bool) {
        switch selection {
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

    // `version` (store revision) forces a rebuild after a silent edit that leaves the count unchanged.
    private var sectionsInput: ListSectionsModel.Input {
        ListSectionsModel.Input(request: listRequest, count: mediaCount,
                                ascending: currentAscending, filter: filterText,
                                mediaFilter: mediaFilter, version: store?.revision ?? 0)
    }
}

#Preview {
    NavigationStack {
        ListContentView(selection: .watched)
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

//
//  ListContentView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Renders the rows, sort/clear toolbar, and filter for a single `ListSelection`.
/// `externalFilter` nil (iPhone) means this view owns its search field; non-nil (iPad) the host supplies it.
struct ListContentView: View {
    let selection: ListSelection
    var externalFilter: String? = nil
    var sortPlacement: ToolbarItemPlacement = .topBarTrailing

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

    private var filterText: String { externalFilter ?? localFilter }

    var body: some View {
        if externalFilter == nil {
            core.searchable(text: $localFilter, prompt: "Search \(title)")
        } else {
            core
        }
    }

    @ViewBuilder
    private var entries: some View {
        if externalFilter == nil {
            ListRows(sections: sectionsModel.sections, selection: selection, lists: lists,
                          listColor: activeColor)
                .listStyle(.plain)
        } else {
            ListGrid(sections: sectionsModel.sections, selection: selection, lists: lists,
                     listColor: activeColor)
        }
    }

    private var core: some View {
        entries
        .tint(activeColor)
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if selection == .viewed {
                ToolbarItem(placement: sortPlacement) {
                    Button(role: .destructive) {
                        store?.clearViewed()
                    } label: {
                        Label("Clear Viewed", systemImage: "trash")
                    }
                    .tint(activeColor)
                    .disabled(movieCount == 0)
                }
            } else {
                ToolbarItem(placement: sortPlacement) {
                    ListSortMenu(ascending: ascendingBinding,
                                 watchedSortKey: selection == .watched ? $watchedSortKey : nil,
                                 listSortKey: isRealList ? listSortKeyBinding : nil)
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
    }

    // MARK: - Derived per-selection

    private var destination: ListDestination { .resolve(selection, lists: lists) }

    private var title: String { destination.name }
    private var activeColor: Color { destination.color }
    private var movieCount: Int { destination.movieCount(using: store) }
    private var sectionSource: SectionSource? {
        destination.sectionSource(watchedByDate: watchedSortKey == .dateWatched,
                                  listByDateAdded: currentListSortKey == .dateAdded)
    }

    private var isRealList: Bool {
        if case .list = selection { return true }
        return false
    }

    private var currentListSortKey: ListSortKey { destination.list?.sortKey ?? .releaseDate }

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
        ListSectionsModel.Input(source: sectionSource, count: movieCount,
                                ascending: currentAscending, filter: filterText,
                                version: store?.revision ?? 0)
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

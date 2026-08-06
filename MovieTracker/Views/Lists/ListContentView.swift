//
//  ListContentView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Renders the rows, sort/clear toolbar, and filter for a single `ListSelection`.
/// Selection ownership and the list switcher live in the host — `ListsView` on
/// iPhone, the sidebar on iPad — so this view is driven purely by the `selection`
/// it's handed.
///
/// When `externalFilter` is `nil` (iPhone) the view owns its own search field.
/// When it's non-`nil` (iPad) the host's single search field supplies the filter
/// text and this view adds no search field of its own.
struct ListContentView: View {
    let selection: ListSelection
    var externalFilter: String? = nil

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var allLists: [MediaList]

    /// Canonical, display-ready lists. `@Query` drives reactivity; the store owns the
    /// decision of which duplicate copies to collapse.
    private var lists: [MediaList] {
        store?.canonicalLists(allLists) ?? allLists.filter { !$0.isDeduplicated }
    }

    /// Builds and holds the month/year section snapshots off the main actor.
    @State private var sectionsModel = ListSectionsModel()
    @State private var localFilter = ""

    @AppStorage("watchedListAscending") private var watchedAscending = false
    @AppStorage("viewedListAscending") private var viewedAscending = false
    @AppStorage("watchedSortKey") private var watchedSortKey: WatchedSortKey = .dateWatched

    /// The active filter: injected by the host on iPad, or the local field on iPhone.
    private var filterText: String { externalFilter ?? localFilter }

    var body: some View {
        if externalFilter == nil {
            core.searchable(text: $localFilter, prompt: "Search \(title)")
        } else {
            core
        }
    }

    private var core: some View {
        ListRows(sections: sectionsModel.sections, selection: selection, lists: lists,
                      listColor: activeColor)
        .listStyle(.plain)
        .tint(activeColor)
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if selection == .viewed {
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
                    ListSortMenu(ascending: ascendingBinding,
                                 watchedSortKey: selection == .watched ? $watchedSortKey : nil,
                                 listSortKey: isRealList ? listSortKeyBinding : nil)
                        .tint(activeColor)
                }
            }
        }
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
        .task(id: sectionsInput) { await sectionsModel.rebuild(for: sectionsInput, store: store) }
        .onChange(of: selection) { _, _ in sectionsModel.clear() }
    }

    // MARK: - Derived per-selection

    /// The current view resolved to its identity + contents; the source of the
    /// title, color, count, empty state, and section source below.
    private var destination: ListDestination { .resolve(selection, lists: lists) }

    private var title: String { destination.name }
    private var activeColor: Color { destination.color }
    private var movieCount: Int { destination.movieCount(using: store) }
    private var sectionSource: SectionSource? {
        destination.sectionSource(watchedByDate: watchedSortKey == .dateWatched,
                                  listByDateAdded: currentListSortKey == .dateAdded)
    }

    /// True for the Watch List and custom lists (real `MediaList`s), false for
    /// the derived Watched / Viewed views.
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

    /// The current build input; `sectionSource` already encodes the selection and
    /// watched-sort key, and the store's `revision` forces a rebuild after a silent
    /// edit (or CloudKit import) that leaves the count unchanged.
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

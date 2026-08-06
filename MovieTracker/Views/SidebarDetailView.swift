//
//  SidebarDetailView.swift
//  MovieTracker
//
//  The iPad detail column. A single search field sits in the trailing nav bar
//  (upper right); when a list is selected it offers an All / this-list scope toggle.
//  The body swaps between global search results, a Discover grid, and list content.
//

import SwiftUI
import SwiftData

struct SidebarDetailView: View {
    let selection: SidebarItem?
    @Binding var scope: SearchScope
    @Binding var path: NavigationPath
    @Bindable var searchModel: SearchModel

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var allLists: [MediaList]

    private var lists: [MediaList] {
        store?.canonicalLists(allLists) ?? allLists.filter { !$0.isDeduplicated }
    }

    var body: some View {
        NavigationStack(path: $path) {
            // Attach search to a stable container *inside* the stack (not the stack
            // itself) so the field renders in the detail's trailing nav bar and the
            // content still lays out full-width.
            ZStack {
                detail
            }
            .detailDestinations()
            .searchable(text: $searchModel.query, prompt: SearchModel.placeholder)
            .searchScopes($scope) {
                Text("All").tag(SearchScope.all)
                if let listName = selectedListName {
                    Text(listName).tag(SearchScope.list)
                }
            }
            .onChange(of: searchModel.query) { _, newValue in
                // Global lookups only run in the All scope; list scope just filters.
                if scope == .all { searchModel.search(newValue) }
            }
            .onChange(of: scope) { _, newScope in
                if newScope == .all { searchModel.search(searchModel.query) }
            }
            .onChange(of: selection) { _, newValue in
                // A collection has no list to filter, so search stays global there.
                if case .list = newValue {} else { scope = .all }
            }
            .onSubmit(of: .search) {
                searchModel.commit()
            }
        }
        // Opening a result (pushing a detail) commits the query to recents.
        .onChange(of: path) { oldPath, newPath in
            if newPath.count > oldPath.count { searchModel.commit() }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if isSearching && scope == .all {
            SearchView(model: searchModel)
        } else {
            switch selection {
            case .list(let listSelection):
                ListContentView(selection: listSelection,
                                 externalFilter: (isSearching && scope == .list) ? searchModel.query : "",
                                 sortPlacement: .topBarLeading)
            case .collection(let collection):
                FeaturedGridView(collection: collection)
            case .none:
                FeaturedGridView(collection: .popular)
            }
        }
    }

    // MARK: - Helpers

    /// The selected list's display name (real, Watched, or Viewed); `nil` for a
    /// Discover collection — which is how the scope toggle is gated.
    private var selectedListName: String? {
        if case .list(let listSelection) = selection {
            return ListDestination.resolve(listSelection, lists: lists).name
        }
        return nil
    }

    private var isSearching: Bool {
        !searchModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    @Previewable @State var scope: SearchScope = .all
    @Previewable @State var path = NavigationPath()
    NavigationStack {
        SidebarDetailView(selection: .list(.watched), scope: $scope, path: $path,
                          searchModel: SearchModel())
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

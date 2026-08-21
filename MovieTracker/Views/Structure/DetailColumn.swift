//
//  DetailColumn.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

struct DetailColumn: View {
    let selection: SidebarItem?
    @Bindable var searchModel: SearchModel

    var body: some View {
        NavigationStack {
            // Search attaches to a stable container inside the stack so the field
            // renders in the trailing nav bar and content still fills the column.
            ZStack {
                DetailContent(selection: selection, searchModel: searchModel)
            }
            .searchable(text: $searchModel.query, placement: .toolbar,
                        prompt: SearchModel.placeholder)
            .onChange(of: searchModel.query) { _, newValue in
                searchModel.search(newValue)
            }
        }
    }
}

/// Its own view because `dismissSearch` only reaches a child of the `.searchable` above.
private struct DetailContent: View {
    let selection: SidebarItem?
    let searchModel: SearchModel

    @Environment(\.dismissSearch) private var dismissSearch

    var body: some View {
        content
            // Picking a sidebar row is a move away from search, so the results give way to the pick.
            .onChange(of: selection) { _, _ in
                guard isSearching else { return }
                dismissSearch()
            }
    }

    @ViewBuilder
    private var content: some View {
        if isSearching {
            SearchView(model: searchModel)
        } else {
            switch selection {
            case .list(let listSelection):
                ListContentView(selection: listSelection,
                                 externalFilter: "",
                                 sortPlacement: .topBarLeading)
            case .collection(let collection):
                FeaturedGridView(collection: collection)
            case .none:
                FeaturedGridView(collection: .nowPlaying)
            }
        }
    }

    private var isSearching: Bool {
        !searchModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    DetailColumn(selection: .list(.watched), searchModel: SearchModel())
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}

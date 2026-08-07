//
//  SidebarContentColumn.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

struct SidebarContentColumn: View {
    let selection: SidebarItem?
    @Bindable var searchModel: SearchModel

    var body: some View {
        NavigationStack {
            // Search attaches to a stable container inside the stack so the field
            // renders in the trailing nav bar and content still fills the column.
            ZStack {
                content
            }
            .searchable(text: $searchModel.query, placement: .toolbar,
                        prompt: SearchModel.placeholder)
            .onChange(of: searchModel.query) { _, newValue in
                searchModel.search(newValue)
            }
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
                FeaturedGridView(collection: .popular)
            }
        }
    }

    private var isSearching: Bool {
        !searchModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    SidebarContentColumn(selection: .list(.watched), searchModel: SearchModel())
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}

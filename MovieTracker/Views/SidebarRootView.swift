//
//  SidebarRootView.swift
//  MovieTracker
//
//  The regular-width (iPad) shell: a sidebar (collections + lists) beside a wide
//  content column (grid or list). Selecting a movie/person opens its detail as a
//  modal sheet rather than a third column.
//

import SwiftUI

struct SidebarRootView: View {
    @Bindable var searchModel: SearchModel

    @State private var selection: SidebarItem? = .collection(.popular)
    @State private var presented: DetailRoot?

    var body: some View {
        NavigationSplitView {
            SidebarColumn(selection: $selection)
        } detail: {
            SidebarContentColumn(selection: selection, searchModel: searchModel)
        }
        .environment(\.openDetail, present)
        .sheet(item: $presented) { root in
            NavigationStack {
                detail(for: root)
                    .modalDismissable()
                    .detailDestinations()
            }
            // Injected on the stack so every pushed screen (cast → person, related
            // → movie) inherits it and keeps its own Close button.
            .environment(\.closeModal) { presented = nil }
            // `.page` is the larger built-in sheet size — the default form sizing
            // left the detail cramped on iPad.
            .presentationSizing(.page)
        }
    }

    /// Opens the tapped result as a modal, committing the query to recents when the
    /// tap came from a search.
    private func present(_ value: AnyHashable) {
        if let movie = value.base as? Movie {
            presented = .movie(movie)
        } else if let person = value.base as? Person {
            presented = .person(person)
        } else if let list = value.base as? PeopleList {
            presented = .people(list)
        } else {
            return
        }
        if !searchModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchModel.commit()
        }
    }

    @ViewBuilder
    private func detail(for root: DetailRoot) -> some View {
        switch root {
        case .movie(let movie): MovieDetailView(movie: movie)
        case .person(let person): PersonDetailView(person: person)
        case .people(let list): SearchPeopleListView(list: list)
        }
    }
}

#Preview {
    SidebarRootView(searchModel: SearchModel())
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .environment(CloudSyncMonitor(isSyncing: false))
        .preferredColorScheme(.dark)
}

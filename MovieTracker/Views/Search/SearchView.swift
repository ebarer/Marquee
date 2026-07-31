//
//  SearchView.swift
//  MovieTracker
//
//  Results list for the unified movie/people search. The search field,
//  scope selector, and query state are owned by RootView's TabView so the
//  search-role tab drives a single search bar for the whole app. When there's
//  no active query, recent searches fill the space instead.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    let model: SearchModel

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\MovieList.sortOrder), SortDescriptor(\MovieList.createdAt)])
    private var lists: [MovieList]

    var body: some View {
        List {
            if isSearching {
                resultRows
            } else {
                recentRows
            }
        }
        .listStyle(.plain)
        .overlay {
            // Nothing typed yet and no history: gently explain the screen.
            if !isSearching && model.recentSearches.isEmpty {
                ContentUnavailableView(
                    "Search Movies & People",
                    systemImage: "magnifyingglass",
                    description: Text("Find movies and cast or crew. Your recent searches will show up here.")
                )
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultRows: some View {
        switch model.scope {
        case .movies:
            ForEach(Array(model.movies.enumerated()), id: \.element.id) { index, movie in
                MovieListRow(
                    movie: movie,
                    lists: lists,
                    context: context,
                    leadingActions: {
                        WatchedSwipeButton(movie: movie, watchedList: watchedList, context: context)
                    },
                    trailingActions: {
                        WatchListSwipeButton(movie: movie, watchList: watchList, context: context)
                    }
                )
                .listRowSeparator(index == 0 ? .hidden : .automatic, edges: .top)
                .listRowSeparator(index == model.movies.count - 1 ? .hidden : .automatic, edges: .bottom)
            }
        case .people:
            ForEach(Array(model.people.enumerated()), id: \.element.id) { index, person in
                NavigationLink(value: person) {
                    PersonRow(person: person)
                }
                .listRowSeparator(index == 0 ? .hidden : .automatic, edges: .top)
                .listRowSeparator(index == model.people.count - 1 ? .hidden : .automatic, edges: .bottom)
            }
        }
    }

    // MARK: - Recent searches

    @ViewBuilder
    private var recentRows: some View {
        if !model.recentSearches.isEmpty {
            Section {
                ForEach(Array(model.recentSearches.enumerated()), id: \.element) { index, term in
                    Button {
                        model.selectRecent(term)
                    } label: {
                        Label(term, systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(index == model.recentSearches.count - 1 ? .hidden : .automatic, edges: .bottom)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            model.removeRecent(term)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Recent")
                    Spacer()
                    Button("Clear") {
                        model.clearRecents()
                    }
                    .textCase(nil)
                }
            }
        }
    }

    // MARK: - List membership

    private var watchList: MovieList? { lists.first { $0.kind == .toWatch } }
    private var watchedList: MovieList? { lists.first { $0.kind == .watched } }

    // MARK: - Helpers

    private var isSearching: Bool {
        !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    NavigationStack {
        SearchView(model: SearchModel())
            .movieTrackerDestinations()
    }
    .modelContainer(previewModelContainer)
    .preferredColorScheme(.dark)
}

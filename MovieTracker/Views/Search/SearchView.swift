//
//  SearchView.swift
//  MovieTracker
//
//  Results for the unified movie/people search. A single query drives both:
//  matching people surface in a strip pinned atop the movie list, so cast and
//  crew are reachable without a scope toggle. People come from name matches and
//  from the characters played in the top movie hits (see SearchModel), so
//  "spiderman" surfaces the actors credited as Spider-Man. The search field and
//  query state are owned by RootView's TabView so the search-role tab drives one
//  search bar for the whole app. When there's no active query, recent searches
//  fill the space.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Bindable var model: SearchModel

    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]

    var body: some View {
        List {
            if isSearching {
                if !featuredPeople.isEmpty {
                    Section("People") {
                        SearchPeopleStrip(people: featuredPeople)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }

                if !model.movies.isEmpty {
                    movieSection
                }
            } else {
                recentRows
            }
        }
        .listStyle(.plain)
        .navigationTitle(isSearching ? "Search: \(trimmedQuery)" : "Search")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isSearching {
                // Only surface "no results" once the lookup settles, so an
                // in-flight query doesn't flash an empty state.
                if !model.isLoading && model.movies.isEmpty && featuredPeople.isEmpty {
                    ContentUnavailableView.search(text: trimmedQuery)
                }
            } else if model.recentSearches.isEmpty {
                ContentUnavailableView(
                    "Search Movies & People",
                    systemImage: "magnifyingglass",
                    description: Text("Find movies and cast or crew. Your recent searches will show up here.")
                )
            }
        }
    }

    // MARK: - Results

    /// People worth showing above the movie results for the current query.
    private var featuredPeople: [Person] {
        model.featuredPeople
    }

    /// Movie results. A "Movies" header only appears when the people strip is
    /// above them, so a plain movie search stays header-free.
    @ViewBuilder
    private var movieSection: some View {
        Section {
            ForEach(Array(model.movies.enumerated()), id: \.element.id) { index, movie in
                MovieListRow(
                    movie: movie,
                    lists: lists,
                    leadingActions: {
                        WatchedSwipeButton(movie: movie)
                    },
                    trailingActions: {
                        WatchListSwipeButton(movie: movie)
                    }
                )
                .listRowSeparator(index == 0 ? .hidden : .automatic, edges: .top)
                .listRowSeparator(index == model.movies.count - 1 ? .hidden : .automatic, edges: .bottom)
            }
        } header: {
            if !featuredPeople.isEmpty {
                Text("Movies")
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

    // MARK: - Helpers

    private var trimmedQuery: String {
        model.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedQuery.isEmpty
    }
}

#Preview {
    NavigationStack {
        SearchView(model: SearchModel())
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

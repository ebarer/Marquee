//
//  SearchView.swift
//  MovieTracker
//
//  Results for the unified movie/people search: a people strip (SearchPeopleStrip)
//  pinned atop the movie list. Query state is owned by RootView's TabView; recent
//  searches fill the space when there's no active query.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Bindable var model: SearchModel

    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]

    @Environment(\.openDetail) private var openDetail
    /// iPad only: the tapped movie row, routed to a modal (see MovieListRow / ListRows).
    @State private var tappedMovie: Movie?

    var body: some View {
        List(selection: openDetail == nil ? .constant(nil) : $tappedMovie) {
            if isSearching {
                if !featuredPeople.isEmpty {
                    Section("People") {
                        SearchPeopleStrip(people: featuredPeople,
                                          inlineCount: model.featuredPeopleInlineCount)
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
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: tappedMovie) { _, movie in
            guard let movie else { return }
            openDetail?(AnyHashable(movie))
            tappedMovie = nil
        }
        .overlay {
            if isSearching {
                if model.movies.isEmpty && featuredPeople.isEmpty {
                    if model.isLoading {
                        // First lookup with nothing to show yet: a spinner beats a
                        // blank screen. (Re-searches keep the prior results visible
                        // until the new ones commit, so this only hits a cold start.)
                        ProgressView()
                    } else {
                        // Only surface "no results" once the lookup settles.
                        ContentUnavailableView.search(text: trimmedQuery)
                    }
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
                    derivesStatus: true,
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

    /// On iPad the search field already displays the query, so repeating it in the
    /// title is redundant; the compact search tab keeps the query for context.
    private var navigationTitle: String {
        if openDetail != nil { return "Search" }
        return isSearching ? "Search: \(trimmedQuery)" : "Search"
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

//
//  SearchView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Bindable var model: SearchModel

    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]

    @Environment(\.openDetail) private var openDetail
    @State private var tappedMovie: Movie?

    var onSelectMovie: ((Movie) -> Void)? = nil

    var body: some View {
        searchList
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
                        ProgressView()
                    } else {
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

    private var featuredPeople: [Person] {
        model.featuredPeople
    }

    @ViewBuilder
    private var movieSection: some View {
        Section {
            ForEach(Array(model.movies.enumerated()), id: \.element.id) { index, movie in
                movieRow(index: index, movie: movie)
            }
        } header: {
            if !featuredPeople.isEmpty {
                Text("Movies")
            }
        }
    }

    @ViewBuilder
    private func movieRow(index: Int, movie: Movie) -> some View {
        MovieListRow(
            movie: movie,
            derivesStatus: true,
            lists: lists,
            leadingActions: { WatchedSwipeButton(movie: movie) },
            trailingActions: { WatchListSwipeButton(movie: movie) },
            onTap: onSelectMovie
        )
        .listRowSeparator(index == 0 ? .hidden : .automatic, edges: .top)
        .listRowSeparator(index == model.movies.count - 1 ? .hidden : .automatic, edges: .bottom)
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

    /// iPhone uses a plain List so rows push; iPad drives selection so a tap opens the modal.
    @ViewBuilder
    private var searchList: some View {
        if openDetail == nil {
            List { listContent }
        } else {
            List(selection: $tappedMovie) { listContent }
        }
    }

    @ViewBuilder
    private var listContent: some View {
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

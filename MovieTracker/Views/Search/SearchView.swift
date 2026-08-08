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
                if model.results.isEmpty && featuredPeople.isEmpty {
                    if model.isLoading {
                        ProgressView()
                    } else {
                        ContentUnavailableView.search(text: trimmedQuery)
                    }
                }
            } else if model.recentSearches.isEmpty {
                ContentUnavailableView(
                    "Search Movies, TV & People",
                    systemImage: "magnifyingglass",
                    description: Text("Find movies, TV, cast, or crew. Your recent searches will show up here.")
                )
            }
        }
    }

    // MARK: - Results

    private var featuredPeople: [Person] {
        model.featuredPeople
    }

    @ViewBuilder
    private var resultsSection: some View {
        Section {
            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, ref in
                resultRow(index: index, ref: ref)
            }
        } header: {
            if !featuredPeople.isEmpty {
                Text("Movies & TV")
            }
        }
    }

    @ViewBuilder
    private func resultRow(index: Int, ref: MediaRef) -> some View {
        let firstEdge: Visibility = index == 0 ? .hidden : .automatic
        let lastEdge: Visibility = index == model.results.count - 1 ? .hidden : .automatic
        switch ref {
        case .movie(let movie):
            MovieListRow(
                movie: movie,
                derivesStatus: true,
                lists: lists,
                leadingActions: { WatchedSwipeButton(movie: movie) },
                trailingActions: { WatchListSwipeButton(movie: movie) },
                onTap: onSelectMovie
            )
            .listRowSeparator(firstEdge, edges: .top)
            .listRowSeparator(lastEdge, edges: .bottom)
        case .show(let show):
            DetailLink(value: show) {
                ShowRow(show: show)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(firstEdge, edges: .top)
            .listRowSeparator(lastEdge, edges: .bottom)
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

            if !model.results.isEmpty {
                resultsSection
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

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
    @Bindable var model: SearchModel

    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]

    /// Measured height of the floating scope bar, used to inset the results so
    /// the first row starts just below it.
    @State private var scopeBarHeight: CGFloat = 0

    /// Gap between the bottom of the scope bar and the first result at rest.
    private let scopeBarGap: CGFloat = 10

    var body: some View {
        List {
            if isSearching {
                resultRows
            } else {
                recentRows
            }
        }
        .listStyle(.plain)
        // Inset the results so the top row rests just below the floating scope
        // bar, but still scrolls up underneath it.
        .contentMargins(.top, isSearching ? scopeBarHeight + scopeBarGap : 0, for: .scrollContent)
        .navigationTitle(isSearching ? "Search: \(trimmedQuery)" : "Search")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            // Own scope bar, z-mounted over the content like the system one,
            // since the system scope bar isn't shown by the bottom-docked tab
            // search field. Kept visible whenever a search is active so the
            // scope can always be switched (e.g. Movies ↔ People).
            if isSearching {
                GlassScopeBar(
                    SearchModel.Scope.allCases,
                    selection: $model.scope,
                    title: \.rawValue
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { scopeBarHeight = $0 }
            }
        }
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
        case .people:
            ForEach(Array(model.people.enumerated()), id: \.element.id) { index, person in
                NavigationLink(value: person) {
                    PersonRow(person: person, showRole: false)
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

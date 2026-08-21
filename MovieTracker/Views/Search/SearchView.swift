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

    // The field floats over the list without insetting it, so the last row lands behind the field.
    @ScaledMetric(relativeTo: .body) private var searchFieldClearance: CGFloat = 56

    var body: some View {
        searchList
        .listStyle(.plain)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
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
                    description: Text("Find movies, TV, cast, or crew. Whatever you open shows up here.")
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
                sectionHeader("Movies & TV")
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .textCase(nil)
            .listRowInsets(SectionHeaderMetrics.listRowInsets)
    }

    @ViewBuilder
    private func resultRow(index: Int, ref: MediaRef) -> some View {
        let firstEdge: Visibility = index == 0 ? .hidden : .automatic
        let lastEdge: Visibility = index == model.results.count - 1 ? .hidden : .automatic
        switch ref {
        case .movie(let movie):
            SearchMovieRow(
                movie: movie,
                lists: lists,
                leadingActions: { WatchedSwipeButton(movie: movie) },
                trailingActions: { WatchListSwipeButton(movie: movie) }
            )
            .listRowSeparator(firstEdge, edges: .top)
            .listRowSeparator(lastEdge, edges: .bottom)
        case .show(let show):
            showRow(show)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(firstEdge, edges: .top)
                .listRowSeparator(lastEdge, edges: .bottom)
        }
    }

    // A result pushes as a button, so no disclosure indicator comes for free.
    private func showRow(_ show: Show) -> some View {
        DetailLink(value: show) {
            HStack(spacing: 8) {
                ShowRow(show: show, derivesStatus: true)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Recent searches

    @ViewBuilder
    private var recentRows: some View {
        if !model.recentSearches.isEmpty {
            Section {
                ForEach(Array(model.recentSearches.enumerated()), id: \.element.id) { index, item in
                    RecentSearchRow(item: item)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(index == model.recentSearches.count - 1 ? .hidden : .automatic,
                                          edges: .bottom)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                model.removeRecent(item)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                }
            } header: {
                HStack {
                    Text("Recent")
                        .font(.headline)
                    Spacer()
                    Button("Clear") {
                        model.clearRecents()
                    }
                }
                .textCase(nil)
                .listRowInsets(SectionHeaderMetrics.listRowInsets)
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

    @ViewBuilder
    private var searchList: some View {
        if openDetail != nil, isSearching {
            SearchResultsGrid(results: model.results, people: featuredPeople,
                              peopleInlineCount: model.featuredPeopleInlineCount, lists: lists)
        } else {
            // The headers' insets set the spacing; section spacing would add to it.
            List { listContent }
                .listSectionSpacing(0)
                .contentMargins(.bottom, openDetail == nil ? searchFieldClearance : 0,
                                for: .scrollContent)
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if isSearching {
            if !featuredPeople.isEmpty {
                Section {
                    SearchPeopleStrip(people: featuredPeople,
                                      inlineCount: model.featuredPeopleInlineCount)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } header: {
                    sectionHeader("People")
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

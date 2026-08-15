//
//  SearchResultsGrid.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The iPad search results: the same cards, columns and spacing as ``ListGrid``, with the people
/// strip above them. The iPhone keeps `SearchView`'s plain rows.
struct SearchResultsGrid: View {
    let results: [MediaRef]
    let people: [Person]
    var peopleInlineCount = 8
    let lists: [MediaList]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if !people.isEmpty {
                    header("People")
                    SearchPeopleStrip(people: people, inlineCount: peopleInlineCount)
                }

                if !results.isEmpty {
                    // Only labelled when the people strip is above it to name what's what.
                    if !people.isEmpty { header("Movies & TV") }
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(results) { ref in
                            card(for: ref)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 16)
        }
        .swipeGridContainer()
    }

    @ViewBuilder
    private func card(for ref: MediaRef) -> some View {
        switch ref {
        case .movie(let movie):
            DetailLink(value: movie) {
                MovieRow(movie: movie, derivesStatus: true)
                    .gridCard()
            }
            .movieContextMenu(for: movie, lists: lists)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                WatchedSwipeButton(movie: movie)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                WatchListSwipeButton(movie: movie)
            }
        case .show(let show):
            DetailLink(value: show) {
                ShowRow(show: show, derivesStatus: true)
                    .gridCard()
            }
        }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
    }
}

#Preview("Movies & TV with people") {
    NavigationStack {
        SearchResultsGrid(results: Movie.previewList.map { .movie($0) } + [.show(.preview)],
                          people: Person.previewTeam, peopleInlineCount: 4, lists: [])
            .background(Color.appBackground)
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Movies & TV only") {
    NavigationStack {
        SearchResultsGrid(results: Movie.previewList.map { .movie($0) }, people: [], lists: [])
            .background(Color.appBackground)
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

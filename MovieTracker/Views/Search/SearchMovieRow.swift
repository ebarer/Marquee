//
//  SearchMovieRow.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A search result's movie row: insets, swipes and the membership menu around a `MovieRow`. Only
/// the iPhone lists results as rows — iPad uses ``SearchResultsGrid``.
struct SearchMovieRow<Leading: View, Trailing: View>: View {
    let movie: Movie
    let lists: [MediaList]
    @ViewBuilder var leadingActions: () -> Leading
    @ViewBuilder var trailingActions: () -> Trailing

    var body: some View {
        // The chevron is drawn here rather than by the list: a result pushes as a button, so no
        // disclosure indicator comes for free. See ``DetailLink``.
        DetailLink(value: movie) {
            HStack(spacing: 8) {
                // Search always derives the badge from the store: a result carries no membership.
                MovieRow(movie: movie, derivesStatus: true)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        // Opt out of selection so a value already on the path doesn't stray-highlight.
        .selectionDisabled()
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .swipeActions(edge: .leading, allowsFullSwipe: true, content: leadingActions)
        .swipeActions(edge: .trailing, allowsFullSwipe: true, content: trailingActions)
        .movieContextMenu(for: movie, lists: lists)
    }
}

#Preview {
    NavigationStack {
        List {
            SearchMovieRow(movie: .preview, lists: [],
                           leadingActions: {
                               WatchedSwipeButton(movie: .preview)
                           }, trailingActions: {
                               WatchListSwipeButton(movie: .preview)
                           })

            SearchMovieRow(movie: Movie.previewList[1], lists: [],
                           leadingActions: { EmptyView() },
                           trailingActions: { EmptyView() })
        }
        .listStyle(.plain)
        .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

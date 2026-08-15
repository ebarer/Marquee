//
//  SearchMovieRow.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A search result's movie row: insets, swipes and the membership menu around a `MovieRow`, plus
/// the tap routing each shell needs. The lists build their rows from `ListEntryRow` instead.
struct SearchMovieRow<Leading: View, Trailing: View>: View {
    let movie: Movie
    let lists: [MediaList]
    @ViewBuilder var leadingActions: () -> Leading
    @ViewBuilder var trailingActions: () -> Trailing

    @Environment(\.openDetail) private var openDetail

    var body: some View {
        if openDetail != nil {
            // iPad: tagged (outermost) so `List(selection:)` routes the tap to a modal.
            decorated.tag(movie)
        } else {
            // iPhone: no selection tag — a tagged link in a selectable List becomes a
            // selection row, and the tap toggles selection instead of pushing.
            decorated
        }
    }

    private var decorated: some View {
        rowContent
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .swipeActions(edge: .leading, allowsFullSwipe: true, content: leadingActions)
            .swipeActions(edge: .trailing, allowsFullSwipe: true, content: trailingActions)
            .movieContextMenu(for: movie, lists: lists)
    }

    @ViewBuilder
    private var rowContent: some View {
        if openDetail == nil {
            // iPhone: a pushing link within the tab's navigation stack. Opt out of
            // selection so a value already on the path doesn't stray-highlight.
            NavigationLink(value: movie) { row }
                .selectionDisabled()
        } else {
            // iPad: `List(selection:)` in the content column turns the tap into a modal —
            // immune to the sync-time re-renders that were swallowing in-row button taps.
            row
        }
    }

    /// Search always derives the badge from the store: a result carries no list membership.
    private var row: some View {
        MovieRow(movie: movie, derivesStatus: true)
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

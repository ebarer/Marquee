//
//  MovieListRow.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

struct MovieListRow<Leading: View, Trailing: View>: View {
    let movie: Movie
    var subtitle: String? = nil
    var role: String? = nil
    var showsSubtitle: Bool = true
    var duration: String? = nil
    var rating: Double? = nil
    var ratingTint: Color = .appAccent
    var status: PosterStatus? = nil
    var derivesStatus: Bool = false
    let lists: [MediaList]
    @ViewBuilder var leadingActions: () -> Leading
    @ViewBuilder var trailingActions: () -> Trailing

    /// When set (iPhone search), the row is a button running this action instead of
    /// a pushing link — the caller resigns the search field's focus and defers the
    /// push so it isn't swallowed by the concurrent keyboard dismissal.
    var onTap: ((Movie) -> Void)? = nil

    @Environment(\.openDetail) private var openDetail

    var body: some View {
        if onTap == nil, openDetail != nil {
            // iPad: tagged (outermost) so `List(selection:)` routes the tap to a modal.
            decorated.tag(movie)
        } else {
            // iPhone: a NavigationLink (or, with `onTap`, a button) in a plain List.
            // No selection tag — a tagged link in a selectable List becomes a
            // selection row and the tap toggles selection instead of pushing.
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
        if let onTap {
            // iPhone search: resign focus + deferred push happens in the action, so
            // the push animates rather than sharing the keyboard-dismissal transaction.
            // A NavigationLink normally supplies the full-row hit area and the trailing
            // chevron; recreate both since this is a plain button.
            Button { onTap(movie) } label: {
                HStack(spacing: 0) {
                    row
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else if openDetail == nil {
            // iPhone: a pushing link within the tab's navigation stack. Opt out of
            // selection so a value already on the path doesn't stray-highlight.
            NavigationLink(value: movie) { row }
                .selectionDisabled()
        } else {
            // iPad: a selectable row. `List(selection:)` in the content column turns
            // the tap into a modal — immune to the sync-time re-renders that were
            // swallowing in-row button taps.
            row
        }
    }

    private var row: some View {
        MovieRow(movie: movie, subtitle: subtitle, role: role,
                 showsSubtitle: showsSubtitle, duration: duration,
                 rating: rating, ratingTint: ratingTint, status: status,
                 derivesStatus: derivesStatus)
    }
}

#Preview {
    NavigationStack {
        List {
            MovieListRow(movie: .preview, lists: [],
                         leadingActions: {
                             WatchedSwipeButton(movie: .preview)
                         }, trailingActions: {
                             WatchListSwipeButton(movie: .preview)
                         })

            MovieListRow(movie: Movie.previewList[1],
                         subtitle: "Watched Aug 2, 2026", role: "Director",
                         duration: "2 hr 53 min", rating: 4.0,
                         lists: [],
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

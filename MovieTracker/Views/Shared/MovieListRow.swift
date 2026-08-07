//
//  MovieListRow.swift
//  MovieTracker
//
//  An interactive movie row for a List: navigation, the shared long-press menu,
//  and caller-supplied swipe actions. Wraps the presentational `MovieRow`; used
//  for both Watch List entries and search results.
//

import SwiftUI
import SwiftData

struct MovieListRow<Leading: View, Trailing: View>: View {
    let movie: Movie
    /// Optional subtitle override (e.g. "Watched <date>"); defaults to release date.
    var subtitle: String? = nil
    /// Optional secondary line below the subtitle (e.g. the person's role in a filmography).
    var role: String? = nil
    /// When false, the row shows no subtitle line at all (no release-date fallback).
    var showsSubtitle: Bool = true
    /// An optional duration line (e.g. "2 hr 8 min") shown beneath the subtitle.
    var duration: String? = nil
    /// The user's personal rating in stars (0.5-step); shown as read-only stars
    /// beneath the subtitle when set.
    var rating: Double? = nil
    /// Fill color for the rating stars.
    var ratingTint: Color = .appAccent
    /// When set, a watched / to-be-watched badge is overlaid on the poster.
    var status: PosterStatus? = nil
    /// When true and no explicit `status` is given, the row derives its own badge
    /// from the persistence store (used for search results).
    var derivesStatus: Bool = false
    let lists: [MediaList]
    @ViewBuilder var leadingActions: () -> Leading
    @ViewBuilder var trailingActions: () -> Trailing

    /// When set (iPhone search), the row is a button running this action instead of
    /// a pushing link — the caller resigns the search field's focus and defers the
    /// push so it isn't swallowed by the concurrent keyboard dismissal.
    var onTap: ((Movie) -> Void)? = nil

    /// Present in the iPad content column, where the row is a tappable button that
    /// fills the detail column; absent on iPhone, where it's a pushing link.
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
            // Halve the default plain-list vertical padding (~11pt) while keeping the
            // standard horizontal inset so alignment and separators are unchanged.
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
            // Plain row: falls back to the release date as its subtitle.
            MovieListRow(movie: .preview, lists: [],
                         leadingActions: {
                             WatchedSwipeButton(movie: .preview)
                         }, trailingActions: {
                             WatchListSwipeButton(movie: .preview)
                         })

            // Enriched row: custom subtitle, role, duration, and a rating.
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

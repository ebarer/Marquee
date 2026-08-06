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

    var body: some View {
        NavigationLink(value: movie) {
            MovieRow(movie: movie, subtitle: subtitle, role: role,
                     showsSubtitle: showsSubtitle, duration: duration,
                     rating: rating, ratingTint: ratingTint, status: status,
                     derivesStatus: derivesStatus)
        }
        // Halve the default plain-list vertical padding (~11pt) while keeping the
        // standard horizontal inset so alignment and separators are unchanged.
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        // A value-based link highlights whenever its value is already on the path
        // (e.g. a filmography listing the movie you came from). We never drive
        // selection off these rows, so opt out to drop that stray highlight.
        .selectionDisabled()
        .swipeActions(edge: .leading, allowsFullSwipe: true, content: leadingActions)
        .swipeActions(edge: .trailing, allowsFullSwipe: true, content: trailingActions)
        .movieContextMenu(for: movie, lists: lists)
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

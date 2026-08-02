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
    let lists: [MediaList]
    let context: ModelContext
    @ViewBuilder var leadingActions: () -> Leading
    @ViewBuilder var trailingActions: () -> Trailing

    var body: some View {
        NavigationLink(value: movie) {
            MovieRow(movie: movie, subtitle: subtitle, role: role,
                     showsSubtitle: showsSubtitle, duration: duration,
                     rating: rating, ratingTint: ratingTint)
        }
        // Halve the default plain-list vertical padding (~11pt) while keeping the
        // standard horizontal inset so alignment and separators are unchanged.
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        // A value-based link renders as "selected" whenever its value is already
        // on the stack's path — e.g. an actor's filmography that lists the movie
        // you navigated in from. Since `Movie` is Hashable by id, that match
        // leaves the row perpetually highlighted. We never drive selection off
        // these rows, so opt them out of selection entirely to drop the highlight
        // while keeping normal push navigation.
        .selectionDisabled()
        .swipeActions(edge: .leading, allowsFullSwipe: true, content: leadingActions)
        .swipeActions(edge: .trailing, allowsFullSwipe: true, content: trailingActions)
        .movieContextMenu(for: movie, lists: lists, context: context)
    }
}

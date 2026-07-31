//
//  MovieListRow.swift
//  MovieTracker
//
//  An interactive movie row in a List context: navigates to the movie detail,
//  shows the shared long-press menu, and hosts caller-supplied leading/trailing
//  swipe actions. Wraps the presentational `MovieRow`. Used for both Watch List
//  entries and movie search results so the two surfaces stay visually and
//  behaviorally identical. Row backgrounds and separators are left to the
//  system/caller so native selection and swipe highlighting behave normally.
//

import SwiftUI
import SwiftData

struct MovieListRow<Leading: View, Trailing: View>: View {
    let movie: Movie
    /// Optional subtitle override (e.g. "Watched <date>"); defaults to release date.
    var subtitle: String? = nil
    let lists: [MovieList]
    let context: ModelContext
    @ViewBuilder var leadingActions: () -> Leading
    @ViewBuilder var trailingActions: () -> Trailing

    var body: some View {
        NavigationLink(value: movie) {
            MovieRow(movie: movie, subtitle: subtitle)
        }
        // Halve the default plain-list vertical padding (~11pt) while keeping the
        // standard horizontal inset so alignment and separators are unchanged.
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .swipeActions(edge: .leading, allowsFullSwipe: true, content: leadingActions)
        .swipeActions(edge: .trailing, allowsFullSwipe: true, content: trailingActions)
        .movieContextMenu(for: movie, lists: lists, context: context)
    }
}

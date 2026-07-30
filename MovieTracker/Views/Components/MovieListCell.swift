//
//  MovieListCell.swift
//  MovieTracker
//
//  A movie row in a List context: navigates to the movie detail, shows the
//  shared long-press menu, and hosts caller-supplied leading/trailing swipe
//  actions. Used for both Watch List entries and movie search results so the
//  two surfaces stay visually and behaviorally identical. Row backgrounds and
//  separators are left to the system/caller so native selection and swipe
//  highlighting behave normally.
//

import SwiftUI
import SwiftData

struct MovieListCell<Leading: View, Trailing: View>: View {
    let movie: Movie
    /// Optional subtitle override (e.g. "Watched <date>"); defaults to release date.
    var subtitle: String? = nil
    let lists: [MovieList]
    let context: ModelContext
    /// Invoked when the row is tapped, alongside navigation (e.g. to commit a search).
    var onSelect: (() -> Void)? = nil
    @ViewBuilder var leadingActions: () -> Leading
    @ViewBuilder var trailingActions: () -> Trailing

    var body: some View {
        NavigationLink(value: movie) {
            MovieRow(movie: movie, subtitle: subtitle)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true, content: leadingActions)
        .swipeActions(edge: .trailing, allowsFullSwipe: true, content: trailingActions)
        .movieContextMenu(for: movie, lists: lists, context: context)
        .simultaneousGesture(TapGesture().onEnded { onSelect?() })
    }
}

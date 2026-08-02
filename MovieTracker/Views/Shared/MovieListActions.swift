//
//  MovieListActions.swift
//  MovieTracker
//
//  Shared movie actions reused across the Featured grid, the Lists screen, and
//  Search results so every surface offers the same swipe actions and long-press
//  context menu.
//

import SwiftUI
import SwiftData

// MARK: - Swipe buttons

/// Leading-swipe action: toggle a movie's Watched state.
struct WatchedSwipeButton: View {
    let movie: Movie
    let context: ModelContext
    @Environment(MediaStore.self) private var store: MediaStore?

    private var isWatched: Bool { MediaItem.isWatched(movie, in: context) }

    var body: some View {
        Button {
            store?.setWatched(!isWatched, for: movie)
        } label: {
            if isWatched {
                Image("checkmark.slashed")
            } else {
                Image(systemName: "checkmark")
            }
        }
        .tint(.appAccent)
    }
}

/// Trailing-swipe action: add a movie to the Watch List.
struct WatchListSwipeButton: View {
    let movie: Movie
    let context: ModelContext
    @Environment(MediaStore.self) private var store: MediaStore?

    var body: some View {
        Button {
            store?.addToWatchList(movie)
        } label: {
            Image(systemName: "bookmark")
        }
        .tint(.appAccent)
    }
}

// MARK: - Context menu

/// The shared long-press menu: toggle Watched and membership across the Watch List
/// and any custom lists.
struct MovieContextMenu: ViewModifier {
    let movie: Movie
    let lists: [MediaList]
    let context: ModelContext

    private var watchList: MediaList? { lists.first { $0.isWatchList } }
    private var customLists: [MediaList] { lists.filter { !$0.isWatchList } }

    func body(content: Content) -> some View {
        content.contextMenu {
            ListMembershipMenu(
                movie: movie,
                watchList: watchList,
                customLists: customLists,
                context: context
            )
        }
    }
}

extension View {
    /// Attaches the shared movie long-press menu (Watched + list membership).
    func movieContextMenu(for movie: Movie, lists: [MediaList], context: ModelContext) -> some View {
        modifier(MovieContextMenu(movie: movie, lists: lists, context: context))
    }
}

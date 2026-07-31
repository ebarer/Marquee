//
//  MovieListActions.swift
//  MovieTracker
//
//  Shared movie/list actions reused across the Featured grid, the Lists screen,
//  and Search results so every surface offers the same swipe actions and
//  long-press context menu.
//

import SwiftUI
import SwiftData

// MARK: - Swipe buttons

/// Leading-swipe action: toggle a movie's Watched state. When the movie is
/// already watched (e.g. an entry in a custom list) the action instead unmarks
/// it, shown with an "unwatch" symbol, rather than pointlessly re-adding it.
struct WatchedSwipeButton: View {
    let movie: Movie
    let watchedList: MovieList?
    let context: ModelContext

    private var isWatched: Bool {
        watchedList.map { WatchListStore.isMember(movie.id, of: $0) } ?? false
    }

    var body: some View {
        Button {
            if let watchedList {
                WatchListStore.toggle(movie, in: watchedList, in: context)
            }
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
    let watchList: MovieList?
    let context: ModelContext

    var body: some View {
        Button {
            if let watchList {
                WatchListStore.add(movie, to: watchList, in: context)
            }
        } label: {
            Image(systemName: "bookmark")
        }
        .tint(.appAccent)
    }
}

// MARK: - Context menu

/// The shared long-press menu for a movie: toggle membership across the Watch
/// List, Watched, and any custom lists, plus create a new list. Hosts its own
/// editor sheet so every screen behaves identically.
struct MovieContextMenu: ViewModifier {
    let movie: Movie
    let lists: [MovieList]
    let context: ModelContext

    @State private var creatingList = false

    private var watchList: MovieList? { lists.first { $0.kind == .toWatch } }
    private var watchedList: MovieList? { lists.first { $0.kind == .watched } }
    private var customLists: [MovieList] { lists.filter { $0.kind == .custom } }

    func body(content: Content) -> some View {
        content
            .contextMenu {
                ListMembershipMenu(
                    movie: movie,
                    watchList: watchList,
                    watchedList: watchedList,
                    customLists: customLists,
                    context: context
                )
            }
            .sheet(isPresented: $creatingList) {
                NavigationStack {
                    ListEditorView(
                        existing: nil,
                        nextSortOrder: (lists.map(\.sortOrder).max() ?? 1) + 1,
                        onSaved: { newList in
                            WatchListStore.add(movie, to: newList, in: context)
                        }
                    )
                }
            }
    }
}

extension View {
    /// Attaches the shared movie long-press menu (membership toggles + New List).
    func movieContextMenu(for movie: Movie, lists: [MovieList], context: ModelContext) -> some View {
        modifier(MovieContextMenu(movie: movie, lists: lists, context: context))
    }
}

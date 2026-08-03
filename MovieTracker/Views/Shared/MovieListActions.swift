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
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    private var isWatched: Bool { store?.isWatched(movie) ?? false }

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
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

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
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    private var canonical: [MediaList] { store?.canonicalLists(lists) ?? lists }
    private var watchList: MediaList? { canonical.first { $0.isWatchList } }
    private var customLists: [MediaList] { canonical.filter { !$0.isWatchList } }

    func body(content: Content) -> some View {
        content.contextMenu {
            ListMembershipMenu(
                movie: movie,
                watchList: watchList,
                customLists: customLists
            )
        }
    }
}

extension View {
    /// Attaches the shared movie long-press menu (Watched + list membership).
    func movieContextMenu(for movie: Movie, lists: [MediaList]) -> some View {
        modifier(MovieContextMenu(movie: movie, lists: lists))
    }
}

#Preview("Swipe actions + context menu") {
    // Swipe a row to reveal the actions; long-press for the membership menu.
    NavigationStack {
        List {
            MovieRow(movie: .preview)
                .swipeActions(edge: .leading) {
                    WatchedSwipeButton(movie: .preview)
                }
                .swipeActions(edge: .trailing) {
                    WatchListSwipeButton(movie: .preview)
                }
                .movieContextMenu(for: .preview, lists: [])
        }
        .listStyle(.plain)
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Buttons") {
    HStack(spacing: 24) {
        WatchedSwipeButton(movie: .preview)
        WatchListSwipeButton(movie: .preview)
    }
    .padding()
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

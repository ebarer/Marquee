//
//  MovieListActions.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

// MARK: - Swipe buttons

struct WatchedSwipeButton: View {
    let key: MediaKey
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    init(key: MediaKey) { self.key = key }
    init(movie: Movie) { self.key = movie.mediaKey }
    init(show: Show) { self.key = show.mediaKey }

    private var isWatched: Bool {
        guard let store else { return false }
        _ = store.revision   // observe persisted changes so the icon doesn't go stale
        return store.isWatched(key: key)
    }

    var body: some View {
        Button {
            store?.setWatched(!isWatched, forKey: key)
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

struct WatchListSwipeButton: View {
    let key: MediaKey
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    init(key: MediaKey) { self.key = key }
    init(movie: Movie) { self.key = movie.mediaKey }
    init(show: Show) { self.key = show.mediaKey }

    var body: some View {
        Button {
            store?.addToWatchList(forKey: key)
        } label: {
            Image(systemName: "bookmark")
        }
        .tint(.appAccent)
    }
}

// MARK: - Context menu

struct MovieContextMenu: ViewModifier {
    let movie: Movie
    let lists: [MediaList]
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    private var canonical: [MediaList] { store?.canonicalLists(lists) ?? lists }
    private var watchList: MediaList? { canonical.first { $0.isWatchList } }
    private var customLists: [MediaList] { canonical.filter { !$0.isWatchList } }

    func body(content: Content) -> some View {
        // Observe persisted changes: a menu rebuilt from a stale snapshot shows stale checkmarks.
        _ = store?.revision
        return content.contextMenu {
            ListMembershipMenu(
                movie: movie,
                watchList: watchList,
                customLists: customLists
            )
        }
    }
}

extension View {
    func movieContextMenu(for movie: Movie, lists: [MediaList]) -> some View {
        modifier(MovieContextMenu(movie: movie, lists: lists))
    }
}

#Preview("Swipe actions + context menu") {
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

//
//  WatchListRows.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The month/year grouped list for the selected list. Rows render from Sendable
/// snapshots; the live entry is only refetched (by persistent id) on delete.
struct WatchListRows: View {
    let sections: [SectionSnapshot]
    /// The selected list; its kind decides the subtitle, rating, and swipe actions.
    let list: MovieList?
    let lists: [MovieList]
    let context: ModelContext
    let listColor: Color
    let watchList: MovieList?
    let watchedList: MovieList?

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                        MovieListRow(
                            movie: movie(from: entry),
                            subtitle: subtitle(for: entry),
                            showsSubtitle: showsRowSubtitle,
                            duration: duration(for: entry),
                            rating: rating(for: entry),
                            ratingTint: listColor,
                            lists: lists,
                            context: context,
                            leadingActions: { leadingAction(for: entry) },
                            trailingActions: {
                                Button(role: .destructive) {
                                    delete(entry)
                                } label: {
                                    Image(systemName: "trash")
                                        .tint(.red)
                                }
                            }
                        )
                        .listRowSeparator(index == section.entries.count - 1 ? .hidden : .automatic, edges: .bottom)
                    }
                } header: {
                    Text(section.title)
                        .foregroundStyle(listColor)
                }
            }
        }
    }

    /// Leading swipe: on Watched, send the movie back to the Watch List; on any
    /// other list, mark it Watched.
    @ViewBuilder
    private func leadingAction(for entry: EntrySnapshot) -> some View {
        let movie = movie(from: entry)
        if list?.kind == .watched {
            WatchListSwipeButton(movie: movie, watchList: watchList, context: context)
        } else {
            WatchedSwipeButton(movie: movie, watchedList: watchedList, context: context)
        }
    }

    private func subtitle(for entry: EntrySnapshot) -> String? {
        guard list?.tracksWatchedDate == true else { return nil }
        return entry.dateWatched.map { "Watched \($0.toString())" }
    }

    /// Watched rows show their own rating; custom-list rows look the movie up on the
    /// Watched list so a rating still shows once seen; other lists show none.
    private func rating(for entry: EntrySnapshot) -> Double? {
        switch list?.kind {
        case .watched:
            return entry.userRating
        case .custom:
            guard let watchedList else { return nil }
            return WatchListStore.rating(for: entry.movieID, in: watchedList)
        default:
            return nil
        }
    }

    private func duration(for entry: EntrySnapshot) -> String? {
        guard list?.kind == .toWatch else { return nil }
        return movie(from: entry).duration
    }

    /// Viewed is a browse history where the release date only adds noise.
    private var showsRowSubtitle: Bool {
        list?.kind != .viewed
    }

    /// Rebuilds a Movie from a snapshot so moves preserve poster/date.
    private func movie(from entry: EntrySnapshot) -> Movie {
        let movie = Movie(id: entry.movieID, title: entry.title)
        movie.poster = entry.posterPath
        movie.releaseDate = entry.releaseDate
        movie.runtime = entry.runtime
        return movie
    }

    private func delete(_ entry: EntrySnapshot) {
        guard let live = context.model(for: entry.persistentID) as? WatchListEntry else { return }
        WatchListStore.delete(live, in: context)
    }
}

// Populated states are exercised by WatchListView's Idle/Syncing previews;
// EntrySnapshot needs a live persistent id that can't be fabricated offline.
#Preview {
    WatchListRows(sections: [],
                  list: MovieList(name: "Watch List", symbol: "bookmark", kind: .toWatch, sortOrder: 0),
                  lists: [], context: previewModelContainer.mainContext, listColor: .appAccent,
                  watchList: nil, watchedList: nil)
        .listStyle(.plain)
}

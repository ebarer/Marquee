//
//  WatchListRows.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The month/year grouped list for the current selection. Rows render from Sendable
/// snapshots; the live model is only refetched (by persistent id) on delete.
struct WatchListRows: View {
    let sections: [SectionSnapshot]
    let selection: ListSelection
    let lists: [MediaList]
    let context: ModelContext
    let listColor: Color
    @Environment(MediaStore.self) private var store: MediaStore?

    private var isWatchList: Bool {
        if case .list(let uuid) = selection { return lists.first { $0.uuid == uuid }?.isWatchList == true }
        return false
    }
    private var isViewed: Bool { selection == .viewed }
    private var isWatched: Bool { selection == .watched }

    var body: some View {
        List {
            // Viewed is a flat recency history — no month sections.
            if isViewed {
                rows(for: sections.first?.entries ?? [])
            } else {
                ForEach(sections) { section in
                    Section {
                        rows(for: section.entries)
                    } header: {
                        Text(section.title)
                            .foregroundStyle(listColor)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rows(for entries: [MediaSnapshot]) -> some View {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
            MovieListRow(
                movie: movie(entry),
                subtitle: subtitle(entry),
                showsSubtitle: !isViewed,
                duration: duration(entry),
                rating: rating(entry),
                ratingTint: listColor,
                lists: lists,
                context: context,
                leadingActions: { leadingAction(entry) },
                trailingActions: {
                    Button(role: .destructive) {
                        delete(entry)
                    } label: {
                        Image(systemName: "trash")
                            .tint(.red)
                    }
                }
            )
            .listRowSeparator(index == entries.count - 1 ? .hidden : .automatic, edges: .bottom)
        }
    }

    /// Leading swipe: on Watched, send back to the Watch List; elsewhere mark Watched.
    @ViewBuilder
    private func leadingAction(_ entry: MediaSnapshot) -> some View {
        if isWatched {
            WatchListSwipeButton(movie: movie(entry), context: context)
        } else {
            WatchedSwipeButton(movie: movie(entry), context: context)
        }
    }

    private func subtitle(_ entry: MediaSnapshot) -> String? {
        guard isWatched, let date = entry.dateWatched else { return nil }
        return "Watched \(date.toString())"
    }

    /// Rating shown on Watched and custom-list rows (looked up from `MediaItem`),
    /// not on the Watch List or Viewed.
    private func rating(_ entry: MediaSnapshot) -> Double? {
        (isWatched || (!isWatchList && !isViewed)) ? entry.userRating : nil
    }

    private func duration(_ entry: MediaSnapshot) -> String? {
        guard isWatchList, let runtime = entry.runtime else { return nil }
        return "\(runtime / 60) hr \(runtime % 60) min"
    }

    private func movie(_ entry: MediaSnapshot) -> Movie {
        let movie = Movie(id: entry.tmdbID, title: entry.title)
        movie.poster = entry.posterPath
        movie.releaseDate = entry.releaseDate
        movie.runtime = entry.runtime
        return movie
    }

    /// Delete depends on the selection: remove the list entry, unmark Watched, or
    /// drop from the Viewed history.
    private func delete(_ entry: MediaSnapshot) {
        switch selection {
        case .list:
            if let live = context.model(for: entry.persistentID) as? ListEntry { store?.delete(live) }
        case .watched:
            if let item = context.model(for: entry.persistentID) as? MediaItem { store?.unwatch(item) }
        case .viewed:
            if let item = context.model(for: entry.persistentID) as? MediaItem { store?.removeFromViewed(item) }
        }
    }
}

#Preview {
    WatchListRows(sections: [], selection: .watched, lists: [],
                  context: previewModelContainer.mainContext, listColor: .appAccent)
        .listStyle(.plain)
}

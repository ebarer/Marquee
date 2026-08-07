//
//  ListRows.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The month/year grouped list for the current selection. Rows render from Sendable
/// snapshots; the live model is only refetched (by persistent id) on delete.
struct ListRows: View {
    let sections: [SectionSnapshot]
    let selection: ListSelection
    let lists: [MediaList]
    let listColor: Color
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Environment(\.openDetail) private var openDetail

    /// iPad only: the row the user tapped. `List(selection:)` sets this even while
    /// the list re-renders during sync, then we open the movie as a modal and clear
    /// it. On iPhone `openDetail` is nil and rows navigate via NavigationLink.
    @State private var tappedMovie: Movie?

    private var isWatchList: Bool {
        if case .list(let uuid) = selection { return lists.first { $0.uuid == uuid }?.isWatchList == true }
        return false
    }
    private var isViewed: Bool { selection == .viewed }
    private var isWatched: Bool { selection == .watched }
    private var isCustomList: Bool {
        if case .list = selection { return !isWatchList }
        return false
    }

    var body: some View {
        if openDetail == nil {
            // iPhone: a plain List so NavigationLink rows push normally.
            List { sectionsContent }
        } else {
            // iPad: selection-driven so the tap opens a modal, immune to the sync-time
            // re-renders that were swallowing in-row taps.
            List(selection: $tappedMovie) { sectionsContent }
                .onChange(of: tappedMovie) { _, movie in
                    guard let movie else { return }
                    openDetail?(AnyHashable(movie))
                    tappedMovie = nil
                }
        }
    }

    @ViewBuilder
    private var sectionsContent: some View {
        // Viewed is a flat recency history — no month sections.
        if isViewed {
            rows(for: sections.first?.entries ?? [], hasHeader: false)
        } else {
            ForEach(sections) { section in
                // A headerless section (e.g. a list ordered by date added)
                // renders its rows flat, with no month header above them.
                if section.title.isEmpty {
                    rows(for: section.entries, hasHeader: false)
                } else {
                    Section {
                        rows(for: section.entries, hasHeader: true)
                    } header: {
                        Text(section.title)
                            .foregroundStyle(listColor)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rows(for entries: [MediaSnapshot], hasHeader: Bool) -> some View {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
            MovieListRow(
                movie: movie(entry),
                subtitle: subtitle(entry),
                showsSubtitle: !isViewed,
                duration: duration(entry),
                rating: rating(entry),
                ratingTint: listColor,
                status: status(entry),
                lists: lists,
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
            // Without a header above them, the first row's top separator floats on
            // its own — hide it so the list starts cleanly.
            .listRowSeparator(!hasHeader && index == 0 ? .hidden : .automatic, edges: .top)
        }
    }

    /// Leading swipe: on Watched, send back to the Watch List; elsewhere mark Watched.
    @ViewBuilder
    private func leadingAction(_ entry: MediaSnapshot) -> some View {
        if isWatched {
            WatchListSwipeButton(movie: movie(entry))
        } else {
            WatchedSwipeButton(movie: movie(entry))
        }
    }

    private func subtitle(_ entry: MediaSnapshot) -> String? {
        guard isWatched, let date = entry.dateWatched else { return nil }
        return "Watched \(date.toString())"
    }

    private func status(_ entry: MediaSnapshot) -> PosterStatus? {
        guard isCustomList else { return nil }
        if entry.dateWatched != nil { return .watched }
        if store?.isInWatchList(movie(entry)) == true { return .watchList }
        return nil
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
        var movie = Movie(id: entry.tmdbID, title: entry.title)
        movie.poster = entry.posterPath
        movie.releaseDate = entry.releaseDate
        movie.runtime = entry.runtime
        return movie
    }

    /// Delete depends on the selection: remove the list entry, unmark Watched, or
    /// drop from the Viewed history.
    private func delete(_ entry: MediaSnapshot) {
        switch selection {
        case .list: store?.deleteEntry(entry.persistentID)
        case .watched: store?.unwatch(entry.persistentID)
        case .viewed: store?.removeFromViewed(entry.persistentID)
        }
    }
}

#Preview {
    ListRows(sections: [], selection: .watched, lists: [], listColor: .appAccent)
        .listStyle(.plain)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
}

//
//  ListGrid.swift
//  MovieTracker
//
//  The iPad list presentation: the same month/year sections and per-entry details
//  as `ListRows`, but each entry is a `MovieGridCard` (poster-left / details-right
//  in a rounded rect) tiled in a grid so the wide content column is used well. Taps
//  route through `DetailLink` (→ the detail modal), reliable in a grid where in-
//  `List` row taps were being swallowed during sync.
//

import SwiftUI
import SwiftData

struct ListGrid: View {
    let sections: [SectionSnapshot]
    let selection: ListSelection
    let lists: [MediaList]
    let listColor: Color
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    // A fixed three-up grid: these detail cards read best at three across, and the
    // count stays stable as the column widens rather than reflowing.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(sections) { section in
                    if !section.title.isEmpty {
                        Text(section.title)
                            .font(.headline)
                            .foregroundStyle(listColor)
                            .padding(.horizontal, 20)
                    }
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(section.entries) { entry in
                            DetailLink(value: movie(entry)) {
                                MovieGridCard(movie: movie(entry),
                                              subtitle: subtitle(entry),
                                              showsSubtitle: !isViewed,
                                              duration: duration(entry),
                                              rating: rating(entry),
                                              ratingTint: listColor,
                                              status: status(entry))
                            }
                            .buttonStyle(.plain)
                            .movieContextMenu(for: movie(entry), lists: lists)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                leadingAction(entry)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { delete(entry) } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 16)
        }
        .modifier(SwipeGridContainer())
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

    /// Remove depends on the selection: drop the list entry, unmark Watched, or
    /// drop from the Viewed history — matching the row list.
    private func delete(_ entry: MediaSnapshot) {
        switch selection {
        case .list: store?.deleteEntry(entry.persistentID)
        case .watched: store?.unwatch(entry.persistentID)
        case .viewed: store?.removeFromViewed(entry.persistentID)
        }
    }

    // MARK: - Per-entry details (mirrors ListRows)

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
}

/// Enables `swipeActions` on the grid's cells (iOS 27+ lets swipe actions work
/// outside a `List`). A no-op on earlier systems, where the cells simply don't swipe.
private struct SwipeGridContainer: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content.swipeActionsContainer()
        } else {
            content
        }
    }
}

#Preview {
    NavigationStack {
        ListGrid(sections: [], selection: .watched, lists: [], listColor: .appAccent)
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

//
//  ListEntrySwipes.swift
//  MovieTracker
//

import SwiftUI

/// The leading swipe an entry offers, as chosen by `ListEntryContext`. Renders nothing when the
/// entry offers none, so the container can attach it unconditionally.
struct ListEntryLeadingSwipe: View {
    let entry: MediaSnapshot
    let context: ListEntryContext
    let actions: ListEntryActions

    var body: some View {
        switch context.leadingSwipe(for: entry) {
        case .markWatched:
            WatchedSwipeButton(movie: entry.movie)
        case .addToWatchList:
            WatchListSwipeButton(movie: entry.movie)
        case .trackedSeason(let season):
            // A full swipe takes the first button, so the next episode leads and the whole season
            // stays a deliberate second tap.
            EpisodeWatchedSwipeButton(showID: entry.tmdbID, seasonNumber: season)
            SeasonWatchedSwipeButton(showID: entry.tmdbID, seasonNumber: season)
        case .toggleShowWatched:
            // A full swipe raises the confirmation; it doesn't sweep every episode on the spot.
            ShowWatchedSwipeButton(showID: entry.tmdbID) { watched in
                actions.requestShowWatched(watched, for: entry)
            }
        case nil:
            EmptyView()
        }
    }
}

/// Trailing swipe for any list entry. Deliberately NOT `role: .destructive`: that promises the
/// entry is going, so the cell clears on tap and tears down its own dialog. Same red, no promise.
struct ListEntryDeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
        }
        .tint(.red)
    }
}

private struct EntrySwipeActions: ViewModifier {
    let entry: MediaSnapshot
    let context: ListEntryContext
    let actions: ListEntryActions

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading,
                          allowsFullSwipe: context.leadingSwipe(for: entry) != nil) {
                ListEntryLeadingSwipe(entry: entry, context: context, actions: actions)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                ListEntryDeleteButton { actions.requestDelete(entry) }
            }
            .listEntryConfirmation(for: entry, actions: actions)
    }
}

extension View {
    /// Both swipes and the confirmation they may raise, identical in the rows and the grid.
    func listEntrySwipes(entry: MediaSnapshot, context: ListEntryContext,
                         actions: ListEntryActions) -> some View {
        modifier(EntrySwipeActions(entry: entry, context: context, actions: actions))
    }

    /// The list-membership menu, for movies only: it files entries as movies, so a show would
    /// land on a list as one.
    @ViewBuilder
    func listEntryContextMenu(for entry: MediaSnapshot, lists: [MediaList]) -> some View {
        if entry.mediaType == .tv {
            self
        } else {
            movieContextMenu(for: entry.movie, lists: lists)
        }
    }
}

#Preview("Swipes") {
    @Previewable @State var pending: ListEntryConfirmation?
    let context = ListEntryContext(selection: .list(UUID()), isWatchList: true,
                                   watchListIDs: [], listColor: .appAccent)
    let store = PersistenceCoordinator(previewModelContainer.mainContext)
    let actions = ListEntryActions(store: store, context: context, pending: $pending)

    NavigationStack {
        List {
            ForEach([MediaSnapshot.preview(id: 1, title: "The Odyssey"),
                     .preview(id: 2, title: "Severance", mediaType: .tv, season: 2,
                              seasonWatched: 3, seasonTotal: 10),
                     .preview(id: 3, title: "Andor", mediaType: .tv)]) { entry in
                ListEntryContent(entry: entry, context: context)
                    .listEntrySwipes(entry: entry, context: context, actions: actions)
            }
        }
        .listStyle(.plain)
    }
    .modelContainer(previewModelContainer)
    .environment(store)
    .preferredColorScheme(.dark)
}

//
//  TVListRow.swift
//  MovieTracker
//

import SwiftUI

/// A TV entry as a list row — a completed season on the Watched list, a list's next-incomplete
/// season, or an untracked show. Only the container differs from the grid's card.
struct TVListRow: View {
    let entry: MediaSnapshot
    let context: ListEntryContext
    let actions: ListEntryActions

    var body: some View {
        ListEntryLink(entry: entry) {
            ListEntryContent(entry: entry, context: context)
        }
        // Multiple seasons of one show push equal `Show` values; opt out of selection so
        // tapping one doesn't stray-highlight another row that shares that value.
        .selectionDisabled()
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listEntrySwipes(entry: entry, context: context, actions: actions)
    }
}

#Preview("TV rows") {
    @Previewable @State var pending: ListEntryConfirmation?
    let context = ListEntryContext(selection: .list(UUID()), isWatchList: true,
                                   watchListIDs: [], listColor: .appAccent)
    let store = PersistenceCoordinator(previewModelContainer.mainContext)
    let actions = ListEntryActions(store: store, context: context, pending: $pending)

    NavigationStack {
        List {
            TVListRow(entry: .preview(id: 1, title: "Severance", mediaType: .tv,
                                      season: 2, seasonWatched: 3, seasonTotal: 10),
                      context: context, actions: actions)
            // Caught up: the next episode hasn't aired, so there's no leading swipe.
            TVListRow(entry: .preview(id: 2, title: "The Studio", mediaType: .tv,
                                      season: 1, seasonWatched: 5, seasonTotal: 8,
                                      nextEpisodeDate: .now.addingTimeInterval(5 * 24 * 3600)),
                      context: context, actions: actions)
            TVListRow(entry: .preview(id: 3, title: "Andor", mediaType: .tv),
                      context: context, actions: actions)
        }
        .listStyle(.plain)
        .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(store)
    .preferredColorScheme(.dark)
}

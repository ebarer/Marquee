//
//  ListEntryRow.swift
//  MovieTracker
//

import SwiftUI

/// One list entry as a `List` row: a movie, a completed season, a list's next-incomplete season,
/// or an untracked show. Only the container differs from the grid's card.
struct ListEntryRow: View {
    let entry: MediaSnapshot
    let context: ListEntryContext
    let actions: ListEntryActions
    let lists: [MediaList]

    var body: some View {
        ListEntryLink(entry: entry) {
            ListEntryContent(entry: entry, context: context)
        }
        // A row can push a value already on the path — two seasons of one show are equal `Show`
        // values. Opt out of selection so tapping one doesn't stray-highlight the other.
        .selectionDisabled()
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listEntryContextMenu(for: entry, lists: lists)
        .listEntrySwipes(entry: entry, context: context, actions: actions)
    }
}

#Preview("Entry rows") {
    @Previewable @State var pending: ListEntryConfirmation?
    let context = ListEntryContext(selection: .list(UUID()), isWatchList: true,
                                   watchListIDs: [], listColor: .appAccent)
    let store = PersistenceCoordinator(previewModelContainer.mainContext)
    let actions = ListEntryActions(store: store, context: context, pending: $pending)

    NavigationStack {
        List {
            ListEntryRow(entry: .preview(id: 1, title: "The Odyssey"),
                         context: context, actions: actions, lists: [])
            ListEntryRow(entry: .preview(id: 2, title: "Severance", mediaType: .tv,
                                         season: 2, seasonWatched: 3, seasonTotal: 10),
                         context: context, actions: actions, lists: [])
            // Caught up: the next episode hasn't aired, so there's no leading swipe.
            ListEntryRow(entry: .preview(id: 3, title: "The Studio", mediaType: .tv,
                                         season: 1, seasonWatched: 5, seasonTotal: 8,
                                         nextEpisodeDate: .now.addingTimeInterval(5 * 24 * 3600)),
                         context: context, actions: actions, lists: [])
            ListEntryRow(entry: .preview(id: 4, title: "Andor", mediaType: .tv),
                         context: context, actions: actions, lists: [])
        }
        .listStyle(.plain)
        .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(store)
    .preferredColorScheme(.dark)
}

//
//  ListEntryLink.swift
//  MovieTracker
//

import SwiftUI

/// One list entry as a tappable link; a TV entry opens the show at the season it is showing.
struct ListEntryLink<Content: View>: View {
    let entry: MediaSnapshot
    @ViewBuilder var content: () -> Content

    var body: some View {
        if entry.mediaType == .tv {
            DetailLink(value: entry.show(openingSeason: entry.seasonNumber), label: content)
        } else {
            DetailLink(value: entry.movie, label: content)
        }
    }
}

#Preview("Links") {
    let context = ListEntryContext(selection: .watched, isWatchList: false,
                                   watchListIDs: [], listColor: ListDestination.watchedColor)
    NavigationStack {
        List {
            ListEntryLink(entry: .preview(id: 1, title: "The Odyssey")) {
                ListEntryContent(entry: .preview(id: 1, title: "The Odyssey"), context: context)
            }
            ListEntryLink(entry: .preview(id: 2, title: "Andor", mediaType: .tv, season: 2)) {
                ListEntryContent(entry: .preview(id: 2, title: "Andor", mediaType: .tv,
                                                 season: 2, seasonWatched: 12, seasonTotal: 12),
                                 context: context)
            }
        }
        .listStyle(.plain)
        .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

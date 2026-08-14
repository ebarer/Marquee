//
//  ListEntryContent.swift
//  MovieTracker
//

import SwiftUI

/// The body for one list entry: a movie, a season, or a show. The rows and the grid render the
/// same content from the same context — only the container chrome around it differs.
struct ListEntryContent: View {
    let entry: MediaSnapshot
    let context: ListEntryContext

    var body: some View {
        if entry.mediaType == .tv {
            if entry.seasonNumber != nil {
                SeasonRowContent(entry: entry, tint: context.listColor)
            } else {
                // An untracked show (e.g. fully watched on a custom list), badged like a movie.
                ShowRow(show: entry.show(), showsSeasonCount: false,
                        status: context.status(for: entry))
            }
        } else {
            MovieRow(movie: entry.movie,
                     subtitle: context.subtitle(for: entry),
                     showsSubtitle: !context.isViewed,
                     duration: context.duration(for: entry),
                     rating: context.rating(for: entry),
                     ratingTint: context.listColor,
                     status: context.status(for: entry))
        }
    }
}

#Preview("Entry bodies") {
    let context = ListEntryContext(selection: .list(UUID()), isWatchList: false,
                                   watchListIDs: [2], listColor: .appAccent)
    List {
        ListEntryContent(entry: .preview(id: 1, title: "The Odyssey", dateWatched: .now,
                                         userRating: 4.5), context: context)
        ListEntryContent(entry: .preview(id: 2, title: "Supergirl"), context: context)
        ListEntryContent(entry: .preview(id: 3, title: "Severance", mediaType: .tv,
                                         season: 2, seasonWatched: 3, seasonTotal: 10),
                         context: context)
        ListEntryContent(entry: .preview(id: 4, title: "Andor", mediaType: .tv), context: context)
    }
    .listStyle(.plain)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

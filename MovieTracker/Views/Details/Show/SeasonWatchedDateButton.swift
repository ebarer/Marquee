//
//  SeasonWatchedDateButton.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The per-season watched date (the season analogue of ``WatchedDateButton``), editing
/// `WatchedSeason.watchedAt`. Shown in the episodes header once a season is complete.
struct SeasonWatchedDateButton: View {
    let showID: Int
    let seasonNumber: Int
    let lastEpisodeDate: Date?
    let tint: Color
    private let initialDate: Date

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    init(showID: Int, seasonNumber: Int, watchedDate: Date?, lastEpisodeDate: Date?, tint: Color) {
        self.showID = showID
        self.seasonNumber = seasonNumber
        self.lastEpisodeDate = lastEpisodeDate
        self.tint = tint
        self.initialDate = watchedDate ?? Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        WatchedDatePicker(initialDate: initialDate, tint: tint, font: .subheadline,
                          quickSetTitle: "Last Episode Date", quickSetDate: lastEpisodeDate) { newValue in
            store?.setSeasonWatchedDate(Calendar.current.startOfDay(for: newValue),
                                        showID: showID, season: seasonNumber)
        }
    }
}

#Preview {
    SeasonWatchedDateButton(showID: 1, seasonNumber: 1, watchedDate: Date(),
                            lastEpisodeDate: Date(), tint: .appAccent)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}

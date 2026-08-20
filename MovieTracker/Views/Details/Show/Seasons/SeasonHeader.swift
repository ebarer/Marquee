//
//  SeasonHeader.swift
//  MovieTracker
//

import SwiftUI

/// The header above a season's episodes: picker, episode count, optional watched date and rating, watched toggle.
struct SeasonHeader: View {
    let seasons: [Season]
    let currentSeason: Int?
    let seasonName: String
    let startYear: Int?
    let episodeCount: Int
    let allWatched: Bool
    var allAiredWatched: Bool = false
    let canToggle: Bool
    let showID: Int
    let seasonWatchedDate: Date?
    let lastEpisodeDate: Date?
    let seasonRating: Double
    let tint: Color
    let onSelectSeason: (Int) -> Void
    let onToggleAll: (Bool) -> Void
    let onRate: (Double?) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            seasonPicker
            Spacer(minLength: 0)
            if allWatched, let current = currentSeason {
                VStack(alignment: .trailing, spacing: 4) {
                    WatchedDateButton(showID: showID, seasonNumber: current,
                                      watchedDate: seasonWatchedDate,
                                      lastEpisodeDate: lastEpisodeDate, tint: tint)
                    StarRating(rating: seasonRating, tint: tint, onCommit: onRate)
                }
                .id(current)
            }
            SeasonWatchedToggle(allWatched: allWatched, allAiredWatched: allAiredWatched,
                                canToggle: canToggle, tint: tint, onToggle: onToggleAll)
        }
        .sectionHeaderInsets()
    }

    // A styled label backed by an embedded Picker: the menu keeps the standard checkmark gutter while
    // the season reads as a section title on the left.
    private var seasonPicker: some View {
        Menu {
            Picker("Season", selection: seasonSelection) {
                // Newest first: on a long-running show the season you're most likely to be
                // watching is at the top of the menu rather than twenty rows down it.
                ForEach(seasons.reversed(), id: \.seasonNumber) { season in
                    Text(season.name).tag(season.seasonNumber)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(seasonName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                }
                Text(yearAndEpisodeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var seasonSelection: Binding<Int> {
        Binding(
            get: { currentSeason ?? seasons.first?.seasonNumber ?? 0 },
            set: { onSelectSeason($0) }
        )
    }

    private var yearAndEpisodeText: String {
        var parts: [String] = []
        if let startYear { parts.append("\(startYear)") }
        parts.append("\(episodeCount) Episode\(episodeCount == 1 ? "" : "s")")
        return parts.joined(separator: "  •  ")
    }
}

#Preview {
    SeasonHeader(seasons: Show.preview.regularSeasons, currentSeason: 1, seasonName: "Season 1",
                 startYear: 2024, episodeCount: 8, allWatched: true, canToggle: true, showID: 1,
                 seasonWatchedDate: Date(), lastEpisodeDate: Date(), seasonRating: 4, tint: .appAccent,
                 onSelectSeason: { _ in }, onToggleAll: { _ in }, onRate: { _ in })
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}

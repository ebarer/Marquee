//
//  EpisodesBySeasonSection.swift
//  MovieTracker
//

import SwiftUI

/// Episodes grouped by season, with a picker (``SeasonHeader``) above a lazily-loaded
/// episode list (``SeasonEpisodeList``).
struct EpisodesBySeasonSection: View {
    let show: Show
    let model: ShowDetailModel
    var tint: Color = .appAccent
    /// A season to open on (e.g. from a Watched-list season row); nil starts at season 1.
    var initialSeason: Int? = nil
    /// Where the season header comes to rest: the bottom edge of the pinned detail header.
    var pinLine: CGFloat = 0
    /// Owned by the detail screen so the header poster can follow the chosen season.
    @Binding var selectedSeason: Int?

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    private var seasons: [Season] { show.regularSeasons }

    private var currentSeason: Int? {
        if let selectedSeason, seasons.contains(where: { $0.seasonNumber == selectedSeason }) {
            return selectedSeason
        }
        if let initialSeason, seasons.contains(where: { $0.seasonNumber == initialSeason }) {
            return initialSeason
        }
        return seasons.first?.seasonNumber
    }

    private var episodes: [Episode]? {
        guard let current = currentSeason else { return nil }
        if let loaded = model.seasonEpisodes[current] { return loaded }
        // Fall back to any episodes embedded on the season (populated in previews; empty
        // from the live endpoint, which triggers a lazy fetch).
        let embedded = seasons.first { $0.seasonNumber == current }?.episodes ?? []
        return embedded.isEmpty ? nil : embedded
    }

    /// The current season with its loaded episodes attached, for watched writes/reconcile.
    private var currentSeasonModel: Season? {
        guard let current = currentSeason,
              var season = seasons.first(where: { $0.seasonNumber == current }) else { return nil }
        if let episodes { season.episodes = episodes }
        return season
    }

    private var currentEpisodes: [Episode] { episodes ?? [] }
    private var currentSeasonObject: Season? { seasons.first { $0.seasonNumber == currentSeason } }

    private var watchedNumbers: Set<Int> {
        guard let store, let current = currentSeason else { return [] }
        _ = store.revision
        return store.watchedEpisodeNumbers(showID: show.id, season: current)
    }

    private var allWatched: Bool {
        !currentEpisodes.isEmpty && currentEpisodes.allSatisfy { watchedNumbers.contains($0.episodeNumber) }
    }

    /// Marking stops at today, so a still-airing season settles here rather than at
    /// `allWatched` — the toggle shows it as caught up instead of complete.
    private var allAiredWatched: Bool {
        let aired = currentEpisodes.filter(\.hasAired)
        return !aired.isEmpty && aired.allSatisfy { watchedNumbers.contains($0.episodeNumber) }
    }

    private var episodeCount: Int {
        if let episodes { return episodes.count }
        return currentSeasonObject?.episodeCount ?? 0
    }

    private var seasonWatchedDate: Date? {
        guard let store, let current = currentSeason else { return nil }
        _ = store.revision
        return store.seasonWatchedDate(showID: show.id, season: current)
    }

    private var seasonRating: Double {
        guard let store, let current = currentSeason else { return 0 }
        _ = store.revision
        return store.seasonRating(showID: show.id, season: current) ?? 0
    }

    var body: some View {
        if !seasons.isEmpty {
            StickySection(space: "scroll", pinLine: pinLine) {
                SeasonHeader(
                    seasons: seasons, currentSeason: currentSeason,
                    seasonName: currentSeasonObject?.name ?? "Season",
                    startYear: currentSeasonObject?.startYear, episodeCount: episodeCount,
                    allWatched: allWatched, allAiredWatched: allAiredWatched,
                    canToggle: !currentEpisodes.isEmpty, showID: show.id,
                    seasonWatchedDate: seasonWatchedDate,
                    lastEpisodeDate: currentEpisodes.compactMap(\.airDate).max(),
                    seasonRating: seasonRating, tint: tint,
                    onSelectSeason: { newValue in withAnimation(.easeInOut) { selectedSeason = newValue } },
                    onToggleAll: applySeasonWatched,
                    onRate: { newValue in
                        if let current = currentSeason {
                            store?.setSeasonRating(newValue, showID: show.id, season: current)
                        }
                    }
                )
            } content: {
                content
            }
            .task(id: currentSeason) {
                if let season = currentSeason {
                    await model.loadSeason(showID: show.id, seasonNumber: season)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let episodes {
            SeasonEpisodeList(episodes: episodes, watchedNumbers: watchedNumbers, tint: tint,
                              onToggle: toggle)
                .transition(.opacity)
                .id(currentSeason)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        }
    }

    private func toggle(_ episode: Episode) {
        guard let store, let season = currentSeasonModel else { return }
        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: episode.episodeNumber)
    }

    private func applySeasonWatched(_ watched: Bool) {
        guard let store, let season = currentSeasonModel else { return }
        withAnimation(.easeInOut) {
            store.setSeasonWatched(watched, show: show, season: season)
        }
    }
}

#Preview {
    @Previewable @State var selectedSeason: Int?
    ScrollView {
        EpisodesBySeasonSection(show: .preview, model: ShowDetailModel(),
                                selectedSeason: $selectedSeason)
    }
    .coordinateSpace(name: "scroll")
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

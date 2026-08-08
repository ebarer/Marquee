//
//  EpisodesBySeasonSection.swift
//  MovieTracker
//

import SwiftUI

/// Episodes grouped by season with a season picker. Episodes for the chosen season load
/// lazily via the model; watched marks persist per episode (`WatchedEpisode`) and a season
/// completing writes its `WatchedSeason` snapshot.
struct EpisodesBySeasonSection: View {
    let show: Show
    let model: ShowDetailModel
    var tint: Color = .appAccent
    /// A season to open on (e.g. from a Watched-list season row); nil starts at season 1.
    var initialSeason: Int? = nil

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @State private var selectedSeason: Int?

    private var seasons: [Season] { show.regularSeasons }

    private var currentSeason: Int? {
        if let selectedSeason, seasons.contains(where: { $0.seasonNumber == selectedSeason }) {
            return selectedSeason
        }
        // Open on the requested season (e.g. tapped in the Watched list), else season 1.
        if let initialSeason, seasons.contains(where: { $0.seasonNumber == initialSeason }) {
            return initialSeason
        }
        return seasons.first?.seasonNumber
    }

    private var episodes: [Episode]? {
        guard let current = currentSeason else { return nil }
        if let loaded = model.seasonEpisodes[current] { return loaded }
        // Fall back to any episodes embedded on the season (populated in previews;
        // empty from the live show endpoint, which triggers a lazy season fetch).
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

    /// Episode numbers watched for the current season (reactive to persisted changes).
    private var watchedNumbers: Set<Int> {
        guard let store, let current = currentSeason else { return [] }
        _ = store.revision
        return store.watchedEpisodeNumbers(showID: show.id, season: current)
    }

    var body: some View {
        if !seasons.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                header
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
            LazyVStack(spacing: 0) {
                ForEach(Array(episodes.enumerated()), id: \.element.id) { index, episode in
                    EpisodeRow(episode: episode,
                               isWatched: watchedNumbers.contains(episode.episodeNumber),
                               tint: tint) {
                        toggle(episode)
                    }
                    if index < episodes.count - 1 { rowSeparator }
                }
            }
            .transition(.opacity)
            .id(currentSeason)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            seasonPicker
            subheader
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    /// A styled label backed by an embedded `Picker` — the menu keeps the standard
    /// checkmark gutter while the season reads as a section title on the left.
    private var seasonPicker: some View {
        Menu {
            Picker("Season", selection: seasonSelection) {
                ForEach(seasons, id: \.seasonNumber) { season in
                    Text(seasonLabel(season)).tag(season.seasonNumber)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(currentSeasonLabel)
                    .font(.headline)
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "n Episodes  •  Mark All as Watched" while in progress; once the season is complete,
    /// the count is replaced by its editable "Watched <date>" (per-season date-watched).
    private var subheader: some View {
        HStack(spacing: 6) {
            if allWatched, let current = currentSeason {
                SeasonWatchedDateButton(showID: show.id, seasonNumber: current,
                                        watchedDate: seasonWatchedDate, tint: tint)
                    .id(current)
            } else {
                Text(episodeCountText)
            }
            Text("•")
            Button {
                withAnimation(.easeInOut) { toggleAllWatched() }
            } label: {
                Text(allWatched ? "Mark All as Unwatched" : "Mark All as Watched")
            }
            .buttonStyle(.plain)
            .foregroundStyle(tint)
            .disabled(currentEpisodes.isEmpty)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    /// The completion date for the current season (reactive to persisted edits).
    private var seasonWatchedDate: Date? {
        guard let store, let current = currentSeason else { return nil }
        _ = store.revision
        return store.seasonWatchedDate(showID: show.id, season: current)
    }

    private var currentSeasonLabel: String {
        guard let current = currentSeason,
              let season = seasons.first(where: { $0.seasonNumber == current }) else { return "Season" }
        return seasonLabel(season)
    }

    private var episodeCount: Int {
        if let episodes { return episodes.count }
        return seasons.first { $0.seasonNumber == currentSeason }?.episodeCount ?? 0
    }

    private var episodeCountText: String {
        "\(episodeCount) Episode\(episodeCount == 1 ? "" : "s")"
    }

    private var allWatched: Bool {
        !currentEpisodes.isEmpty && currentEpisodes.allSatisfy { watchedNumbers.contains($0.episodeNumber) }
    }

    private func toggle(_ episode: Episode) {
        guard let store, let season = currentSeasonModel else { return }
        store.toggleEpisodeWatched(show: show, season: season, episodeNumber: episode.episodeNumber)
    }

    private func toggleAllWatched() {
        guard let store, let season = currentSeasonModel else { return }
        store.setSeasonWatched(!allWatched, show: show, season: season)
    }

    private var seasonSelection: Binding<Int> {
        Binding(
            get: { currentSeason ?? seasons.first?.seasonNumber ?? 0 },
            set: { newValue in withAnimation(.easeInOut) { selectedSeason = newValue } }
        )
    }

    private func seasonLabel(_ season: Season) -> String {
        if let year = season.startYear { return "\(season.name) (\(year))" }
        return season.name
    }

    private var rowSeparator: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }
}

#Preview {
    ScrollView {
        EpisodesBySeasonSection(show: .preview, model: ShowDetailModel())
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

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
    /// Owned by the detail screen so the header poster can follow the chosen season.
    @Binding var selectedSeason: Int?

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    /// Non-nil while a mark-season-watched (true) / unmark (false) confirmation is pending.
    @State private var pendingSeasonWatched: Bool?

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
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                seasonPicker
                subheader
            }
            Spacer(minLength: 0)
            if allWatched, let current = currentSeason {
                VStack(alignment: .trailing, spacing: 4) {
                    SeasonWatchedDateButton(showID: show.id, seasonNumber: current,
                                            watchedDate: seasonWatchedDate,
                                            lastEpisodeDate: lastEpisodeDate, tint: tint)
                    StarRating(rating: seasonRating, tint: tint) { newValue in
                        store?.setSeasonRating(newValue, showID: show.id, season: current)
                    }
                }
                .id(current)
            }
            seasonWatchedToggle
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
                    Text(season.name).tag(season.seasonNumber)
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

    /// "<year> • <episode count>" beneath the season picker.
    private var subheader: some View {
        Text(yearAndEpisodeText)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    /// A glass checkmark toggling the whole season's watched state, mirroring the
    /// show-level checkmark — confirmed before marking on or off.
    private var seasonWatchedToggle: some View {
        Button {
            pendingSeasonWatched = !allWatched
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(allWatched ? .appBackground : tint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(allWatched ? .regular.tint(tint).interactive() : .regular.interactive(),
                     in: Circle())
        .disabled(currentEpisodes.isEmpty)
        .accessibilityLabel(allWatched ? "Mark season unwatched" : "Mark season watched")
        .confirmationDialog(
            pendingSeasonWatched == true ? "Mark season as watched?" : "Mark season as unwatched?",
            isPresented: Binding(get: { pendingSeasonWatched != nil },
                                 set: { if !$0 { pendingSeasonWatched = nil } }),
            titleVisibility: .visible) {
            if pendingSeasonWatched == true {
                Button("Mark Watched") { applySeasonWatched(true) }
            } else {
                Button("Mark Unwatched", role: .destructive) { applySeasonWatched(false) }
            }
            Button("Cancel", role: .cancel) { pendingSeasonWatched = nil }
        }
    }

    /// The completion date for the current season (reactive to persisted edits).
    private var seasonWatchedDate: Date? {
        guard let store, let current = currentSeason else { return nil }
        _ = store.revision
        return store.seasonWatchedDate(showID: show.id, season: current)
    }

    /// The latest episode air date in the current season, offered in the date picker.
    private var lastEpisodeDate: Date? {
        currentEpisodes.compactMap(\.airDate).max()
    }

    /// The current season's star rating (reactive to persisted edits).
    private var seasonRating: Double {
        guard let store, let current = currentSeason else { return 0 }
        _ = store.revision
        return store.seasonRating(showID: show.id, season: current) ?? 0
    }

    private var currentSeasonObject: Season? {
        seasons.first { $0.seasonNumber == currentSeason }
    }

    private var currentSeasonLabel: String {
        currentSeasonObject?.name ?? "Season"
    }

    private var episodeCount: Int {
        if let episodes { return episodes.count }
        return currentSeasonObject?.episodeCount ?? 0
    }

    private var episodeCountText: String {
        "\(episodeCount) Episode\(episodeCount == 1 ? "" : "s")"
    }

    private var yearAndEpisodeText: String {
        var parts: [String] = []
        if let year = currentSeasonObject?.startYear { parts.append("\(year)") }
        parts.append(episodeCountText)
        return parts.joined(separator: "  •  ")
    }

    private var allWatched: Bool {
        !currentEpisodes.isEmpty && currentEpisodes.allSatisfy { watchedNumbers.contains($0.episodeNumber) }
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
        pendingSeasonWatched = nil
    }

    private var seasonSelection: Binding<Int> {
        Binding(
            get: { currentSeason ?? seasons.first?.seasonNumber ?? 0 },
            set: { newValue in withAnimation(.easeInOut) { selectedSeason = newValue } }
        )
    }

    private var rowSeparator: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }
}

#Preview {
    @Previewable @State var selectedSeason: Int?
    ScrollView {
        EpisodesBySeasonSection(show: .preview, model: ShowDetailModel(),
                                selectedSeason: $selectedSeason)
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

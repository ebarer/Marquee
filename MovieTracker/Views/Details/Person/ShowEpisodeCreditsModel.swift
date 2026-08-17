//
//  ShowEpisodeCreditsModel.swift
//  MovieTracker
//

import Foundation

@MainActor
@Observable
final class ShowEpisodeCreditsModel {
    /// One season's worth of the credit: the full season (watched writes reconcile against
    /// it) paired with only the episodes the person appears in.
    struct Group: Identifiable {
        let season: Season
        let episodes: [Episode]
        var id: Int { season.id }
    }

    private(set) var groups: [Group] = []
    /// The fuller show, resolved for its season list — the credit stub carries none, and
    /// membership reconciliation reads it on every watched toggle.
    private(set) var show: Show?
    private(set) var isLoading = false
    /// Distinguishes "still fetching" from "fetched, and the person has no episodes here".
    private(set) var hasLoaded = false

    func load(_ credit: ShowEpisodeCredits) async {
        guard groups.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false; hasLoaded = true }

        show = await ShowSeasonCountStore.shared.show(for: credit.show.id)

        var resolved = credit.credit
        if resolved == nil {
            resolved = await EpisodeCreditStore.shared.credit(for: credit.show)
        }
        guard let resolved else { return }

        var loaded: [Group] = []
        for seasonCredit in resolved.credited {
            let number = seasonCredit.season.seasonNumber
            guard let season = try? await TMDBWrapper.getSeason(showID: credit.show.id,
                                                                seasonNumber: number) else { continue }
            let episodes = season.episodes
                .filter { seasonCredit.covers(episode: $0.episodeNumber) }
                .sorted { $0.episodeNumber > $1.episodeNumber }
            if !episodes.isEmpty { loaded.append(Group(season: season, episodes: episodes)) }
        }
        groups = loaded.sorted { $0.season.seasonNumber > $1.season.seasonNumber }
    }

    /// Previews only: a model already holding its groups, so the screen renders offline.
    static func preview(show: Show, groups: [Group]) -> ShowEpisodeCreditsModel {
        let model = ShowEpisodeCreditsModel()
        model.show = show
        model.groups = groups
        model.hasLoaded = true
        return model
    }
}

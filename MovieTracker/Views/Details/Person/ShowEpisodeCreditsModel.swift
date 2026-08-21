//
//  ShowEpisodeCreditsModel.swift
//  MovieTracker
//

import Foundation

@MainActor
@Observable
final class ShowEpisodeCreditsModel {
    struct Group: Identifiable {
        let season: Season
        let episodes: [Episode]
        var role: String? = nil
        var id: Int { season.id }
    }

    private(set) var groups: [Group] = []
    // The credit stub carries no season list, and membership reconciliation reads it on every watched toggle.
    private(set) var show: Show?
    private(set) var isLoading = false
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
        if resolved == nil, let person = credit.person {
            resolved = await EpisodeCreditStore.shared.credit(person: person.id, in: credit.show)
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
            if !episodes.isEmpty {
                loaded.append(Group(season: season, episodes: episodes,
                                    role: role(for: seasonCredit, in: credit)))
            }
        }
        groups = loaded.sorted { $0.season.seasonNumber > $1.season.seasonNumber }
    }

    // TMDB's credit ids for one show can carry different characters, and the credit's own role joins
    // them all, so a season shows the character of the credit it came from.
    private func role(for seasonCredit: EpisodeCredit.SeasonCredit,
                      in credit: ShowEpisodeCredits) -> String? {
        guard let roles = credit.show.creditRolesByID, !roles.isEmpty else {
            return credit.show.creditRole
        }
        return seasonCredit.creditID.flatMap { roles[$0] }
    }

    static func preview(show: Show, groups: [Group]) -> ShowEpisodeCreditsModel {
        let model = ShowEpisodeCreditsModel()
        model.show = show
        model.groups = groups
        model.hasLoaded = true
        return model
    }
}

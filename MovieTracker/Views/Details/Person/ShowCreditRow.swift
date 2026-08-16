//
//  ShowCreditRow.swift
//  MovieTracker
//

import SwiftUI

/// One TV credit in a person's filmography. "3 Episodes" says nothing you can act on, so the
/// row resolves the count into the episode itself, the season, or a pushable episode list.
struct ShowCreditRow: View {
    let show: Show
    /// Resolved by the person screen before the rows are laid out, since a row's year
    /// section depends on it.
    var credit: EpisodeCredit? = nil
    /// The one season this row stands for, where the credit spans several years.
    var season: EpisodeCredit.SeasonCredit? = nil

    var body: some View {
        NavigationLink(value: destination) {
            HStack(spacing: 8) {
                ShowRow(show: show, role: show.creditRole, showsSeasonCount: false,
                        episodeSummary: summary, posterOverride: seasonPoster)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.rowPress)
    }

    /// Every TV credit opens the episode list, since the show can't say which episodes they
    /// were in — bar a credit with no ids behind it, which has no episodes to list.
    private var destination: ShowCreditDestination {
        guard !show.creditIDs.isEmpty else { return .show(show) }
        return .episodes(ShowEpisodeCredits(show: show, credit: credit))
    }

    /// A season stood up from its episodes alone carries no art, so the show's stands in.
    private var seasonPoster: URL? { season?.season.posterURL(.w185) }

    /// The season where the row stands for one, else the whole credit; TMDB's declared count
    /// is the fallback for a credit with no episode detail behind it.
    private var summary: String? {
        if let label = season?.label ?? credit?.summary?.label { return label }
        guard let count = show.episodeCount, count > 0 else { return nil }
        return EpisodeCredit.episodeCountLabel(count)
    }
}

#Preview {
    func show(_ id: Int, _ name: String, _ role: String, _ count: Int) -> Show {
        var show = Show(id: id, name: name)
        show.poster = "preview-poster"
        show.creditRole = role
        show.episodeCount = count
        return show
    }

    let seasons = Season.previewSeasons

    return NavigationStack {
        ScrollView {
            LazyVStack(spacing: 0) {
                // No episode detail behind it: TMDB's declared count.
                ShowCreditRow(show: show(2001, "Punk'd", "Self", 1))
                ShowCreditRow(show: show(2002, "The Studio", "Olivia Wilde", 1),
                              credit: EpisodeCredit(seasons: [
                                  .init(season: seasons[0], episodeNumbers: [2]),
                              ]))
                // A run split per season, as the filmography lists it under each year.
                ShowCreditRow(show: show(2004, "The O.C.", "Alex Kelly", 13),
                              season: .init(season: seasons[1]))
                ShowCreditRow(show: show(2004, "The O.C.", "Alex Kelly", 13),
                              season: .init(season: seasons[2], episodeNumbers: [2, 4]))
            }
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

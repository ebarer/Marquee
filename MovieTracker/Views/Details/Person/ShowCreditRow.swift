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

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    // The swipe is attached only when there's something to do: outside a `List`, an empty
    // `swipeActions` still takes the gesture, and the row rubber-bands for no offered action.
    @ViewBuilder
    var body: some View {
        if let completableSeason {
            link.swipeActions(edge: .leading, allowsFullSwipe: true) {
                SeasonWatchedSwipeButton(showID: show.id, seasonNumber: completableSeason)
            }
        } else {
            link
        }
    }

    private var link: some View {
        NavigationLink(value: destination) {
            HStack(spacing: 8) {
                // Show-level even on a season row, so a series reads the same here as it does
                // in search and the lists.
                ShowRow(show: show, role: show.creditRole, showsSeasonCount: false,
                        episodeSummary: summary, posterOverride: seasonPoster,
                        derivesStatus: true)
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

    /// The season this row can complete, mirroring the lists: nothing on a finished season, a
    /// caught-up show, or a season still airing, which would be completed early.
    private var completableSeason: Int? {
        guard let season, let store else { return nil }
        let number = season.season.seasonNumber
        guard !store.badges.isSeasonWatched(showID: show.id, seasonNumber: number),
              !store.badges.isShowCaughtUp(showID: show.id),
              !season.season.episodes.contains(where: { !$0.hasAired })
        else { return nil }
        return number
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
                // A guest spot, split per season as the filmography splits it.
                ShowCreditRow(show: show(2002, "The Studio", "Olivia Wilde", 1),
                              credit: EpisodeCredit(seasons: [
                                  .init(season: seasons[0], episodeNumbers: [2]),
                              ]),
                              season: .init(season: seasons[0], episodeNumbers: [2]))
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

// Watched and in-progress, seeded before the coordinator whose badge index reads them. No Watch
// List row: its entry matches through a relationship predicate, which a pending insert won't.
#Preview("Tracked") {
    func show(_ id: Int, _ name: String, _ role: String) -> Show {
        var show = Show(id: id, name: name)
        show.poster = "preview-poster"
        show.creditRole = role
        show.episodeCount = 8
        return show
    }

    let watched = show(3001, "Severance", "Mark Scout")
    let inProgress = show(3002, "Andor", "Cassian Andor")
    let untracked = show(3003, "The Studio", "Matt Remick")

    let context = previewModelContainer.mainContext
    let item = MediaItem(key: watched.mediaKey)
    item.showWatched = true
    context.insert(item)
    context.insert(WatchedEpisode(showTmdbID: inProgress.id, seasonNumber: 1, episodeNumber: 1))

    return NavigationStack {
        ScrollView {
            LazyVStack(spacing: 0) {
                ShowCreditRow(show: watched)
                ShowCreditRow(show: inProgress)
                ShowCreditRow(show: untracked)
            }
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(context))
    .preferredColorScheme(.dark)
}

// Interactive: only the second row swipes. A finished season offers nothing, and neither does a
// caught-up show, whose every aired episode is already watched.
#Preview("Swipes") {
    func show(_ id: Int, _ name: String, _ role: String) -> Show {
        var show = Show(id: id, name: name)
        show.poster = "preview-poster"
        show.creditRole = role
        return show
    }

    let seasons = Season.previewSeasons
    let finished = show(4001, "The O.C.", "Alex Kelly")
    let unfinished = show(4002, "Euphoria", "Rue Bennett")
    let caughtUp = show(4003, "Ted Lasso", "Rebecca Welton")

    let context = previewModelContainer.mainContext
    context.insert(WatchedSeason(showTmdbID: finished.id, seasonNumber: 2, showName: finished.name,
                                 seasonName: "Season 2", posterPath: nil, airDate: nil,
                                 episodeCount: 10))
    let item = MediaItem(key: caughtUp.mediaKey)
    item.showCaughtUp = true
    context.insert(item)
    context.insert(WatchedEpisode(showTmdbID: caughtUp.id, seasonNumber: 3, episodeNumber: 1))

    return NavigationStack {
        ScrollView {
            LazyVStack(spacing: 0) {
                ShowCreditRow(show: finished, season: .init(season: seasons[1]))
                ShowCreditRow(show: unfinished, season: .init(season: seasons[2]))
                ShowCreditRow(show: caughtUp, season: .init(season: seasons[2]))
            }
        }
        .swipeGridContainer()
        .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(context))
    .preferredColorScheme(.dark)
}

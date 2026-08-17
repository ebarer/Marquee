//
//  DetailRoot.swift
//  MovieTracker
//

import SwiftUI

/// A detail screen the iPad shell presents modally.
enum DetailRoot: Hashable, Identifiable {
    case movie(Movie)
    case show(Show)
    case episode(Episode)
    case person(Person)
    case people(PeopleList)
    case episodeCredits(ShowEpisodeCredits)

    var id: String {
        switch self {
        case .movie(let movie): return "movie-\(movie.id)"
        case .show(let show): return "show-\(show.id)"
        case .episode(let episode): return "episode-\(episode.id)"
        case .person(let person): return "person-\(person.id)"
        case .people(let list): return "people-\(list.title)"
        case .episodeCredits(let credit): return "credit-\(credit.show.id)"
        }
    }

    /// Maps a type-erased navigation value to a detail root, if it's a known kind.
    init?(_ value: AnyHashable) {
        switch value.base {
        case let movie as Movie: self = .movie(movie)
        case let show as Show: self = .show(show)
        case let episode as Episode: self = .episode(episode)
        case let person as Person: self = .person(person)
        case let list as PeopleList: self = .people(list)
        case let credit as ShowEpisodeCredits: self = .episodeCredits(credit)
        case .show(let show) as ShowCreditDestination: self = .show(show)
        case .episodes(let credit) as ShowCreditDestination: self = .episodeCredits(credit)
        default: return nil
        }
    }
}

/// The detail screen for a `DetailRoot` — the modal's content router.
struct DetailRootView: View {
    let root: DetailRoot

    // Whatever this renders is what the modal opened on — nothing is pushed over it yet, so
    // its Close button owns the leading side.
    var body: some View {
        destination
            .environment(\.isModalRoot, true)
    }

    // Close is attached per case, not to the whole router: the person screen renders its own,
    // after the filter button, so an outer copy would double up.
    @ViewBuilder
    private var destination: some View {
        switch root {
        case .movie(let movie): MovieDetailView(movie: movie).detailSearchHost()
        case .show(let show): ShowDetailView(show: show).modalDismissable().detailSearchHost()
        case .episode(let episode):
            EpisodeDetailView(episode: episode).modalDismissable().detailSearchHost()
        case .person(let person): PersonDetailView(person: person).detailSearchHost()
        case .people(let list): SearchPeopleListView(list: list).modalDismissable()
        case .episodeCredits(let credit): ShowEpisodeCreditsView(credit: credit).modalDismissable()
        }
    }
}

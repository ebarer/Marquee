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

    var id: String {
        switch self {
        case .movie(let movie): return "movie-\(movie.id)"
        case .show(let show): return "show-\(show.id)"
        case .episode(let episode): return "episode-\(episode.id)"
        case .person(let person): return "person-\(person.id)"
        case .people(let list): return "people-\(list.title)"
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
        default: return nil
        }
    }
}

/// The detail screen for a `DetailRoot` — the modal's content router.
struct DetailRootView: View {
    let root: DetailRoot

    // Close is attached per case, not to the whole router: the person screen renders its own,
    // after the filter button, so an outer copy would double up.
    var body: some View {
        switch root {
        case .movie(let movie): MovieDetailView(movie: movie).modalDismissable()
        case .show(let show): ShowDetailView(show: show).modalDismissable()
        case .episode(let episode): EpisodeDetailView(episode: episode).modalDismissable()
        case .person(let person): PersonDetailView(person: person)
        case .people(let list): SearchPeopleListView(list: list).modalDismissable()
        }
    }
}

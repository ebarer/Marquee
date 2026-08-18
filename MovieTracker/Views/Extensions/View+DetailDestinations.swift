//
//  View+DetailDestinations.swift
//  MovieTracker
//

import SwiftUI

extension View {
    func detailDestinations() -> some View {
        self
            // Hosted here, not inside each page, so a page can read `\.detailSearch` itself.
            // Movie, show and person render Close themselves, after their own trailing items.
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailView(movie: movie).detailSearchHost()
            }
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(show: show).detailSearchHost()
            }
            .navigationDestination(for: Episode.self) { episode in
                EpisodeDetailView(episode: episode).modalDismissable().detailSearchHost()
            }
            .navigationDestination(for: Person.self) { person in
                PersonDetailView(person: person).detailSearchHost()
            }
            .navigationDestination(for: PeopleList.self) { list in
                SearchPeopleListView(list: list).modalDismissable()
            }
            .navigationDestination(for: ShowCreditDestination.self) { destination in
                switch destination {
                case .show(let show): ShowDetailView(show: show).detailSearchHost()
                case .episodes(let credit): ShowEpisodeCreditsView(credit: credit).modalDismissable()
                }
            }
    }
}

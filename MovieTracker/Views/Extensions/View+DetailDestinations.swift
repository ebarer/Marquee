//
//  View+DetailDestinations.swift
//  MovieTracker
//

import SwiftUI

extension View {
    func detailDestinations() -> some View {
        self
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailView(movie: movie).modalDismissable()
            }
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(show: show).modalDismissable()
            }
            .navigationDestination(for: Episode.self) { episode in
                EpisodeDetailView(episode: episode).modalDismissable()
            }
            // No `modalDismissable()`: the person screen renders Close itself, after its filter.
            .navigationDestination(for: Person.self) { person in
                PersonDetailView(person: person)
            }
            .navigationDestination(for: PeopleList.self) { list in
                SearchPeopleListView(list: list).modalDismissable()
            }
    }
}

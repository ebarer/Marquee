//
//  View+DetailDestinations.swift
//  MovieTracker
//

import SwiftUI

extension View {
    /// Registers the shared movie / person / people-list detail destinations on a
    /// navigation stack, so any shell (tab bar or sidebar) pushes them the same way.
    func detailDestinations() -> some View {
        self
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailView(movie: movie)
            }
            .navigationDestination(for: Person.self) { person in
                PersonDetailView(person: person)
            }
            .navigationDestination(for: PeopleList.self) { list in
                SearchPeopleListView(list: list)
            }
    }
}

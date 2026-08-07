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
            .navigationDestination(for: Person.self) { person in
                PersonDetailView(person: person).modalDismissable()
            }
            .navigationDestination(for: PeopleList.self) { list in
                SearchPeopleListView(list: list).modalDismissable()
            }
    }
}

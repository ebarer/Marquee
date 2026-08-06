//
//  SearchPeopleListView.swift
//  MovieTracker
//
//  The full list of people for a query, pushed from the "More" button at the end
//  of the search people strip. The strip previews only the top-ranked few inline;
//  this shows everyone, in the same ranked order.
//

import SwiftUI

/// A navigable value carrying the complete people list behind the strip's "More"
/// button. Person is Hashable/Codable, so this synthesizes both for free.
struct PeopleList: Hashable {
    let title: String
    let people: [Person]
}

struct SearchPeopleListView: View {
    let list: PeopleList

    var body: some View {
        List(list.people) { person in
            NavigationLink(value: person) {
                PersonRow(person: person)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .navigationTitle(list.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SearchPeopleListView(list: PeopleList(title: "People", people: Person.previewTeam))
            .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

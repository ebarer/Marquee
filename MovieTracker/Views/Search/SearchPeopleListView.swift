//
//  SearchPeopleListView.swift
//  MovieTracker
//

import SwiftUI

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

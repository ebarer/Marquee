//
//  SearchPeopleStrip.swift
//  MovieTracker
//
//  Horizontal row of matching people shown atop the search results, so cast and
//  crew surface alongside movies without a scope toggle. Movies remain the main
//  list below; this strip only appears when the query matches names.
//

import SwiftUI

struct SearchPeopleStrip: View {
    let people: [Person]

    private let itemWidth: CGFloat = 76
    private let profileSize: CGFloat = 64

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(people, id: \.id) { person in
                    NavigationLink(value: person) {
                        VStack(spacing: 6) {
                            ProfileImage(url: person.profileURL())
                                .frame(width: profileSize, height: profileSize)

                            Text(person.name)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(width: itemWidth)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    NavigationStack {
        SearchPeopleStrip(people: Person.previewTeam)
            .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

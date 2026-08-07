//
//  SearchPeopleStrip.swift
//  MovieTracker
//
//  Horizontal strip of matching people atop the movie results (no scope toggle).
//  Shows the top-ranked few inline; a trailing circular "More" button pushes the
//  full list when there are extras.
//

import SwiftUI

struct SearchPeopleStrip: View {
    let people: [Person]

    /// How many people show inline before the rest fold behind "More". This is a
    /// notability count computed by the model (see SearchMatching.inlinePeopleCount),
    /// so low-popularity namesakes fold even when the total is small.
    var inlineCount = 8

    private let itemWidth: CGFloat = 76
    private let profileSize: CGFloat = 64

    private var preview: ArraySlice<Person> {
        people.prefix(inlineCount)
    }

    private var hiddenCount: Int {
        max(0, people.count - inlineCount)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(preview, id: \.id) { person in
                    DetailLink(value: person) {
                        personCell(person)
                    }
                    .buttonStyle(.plain)
                }

                if hiddenCount > 0 {
                    DetailLink(value: PeopleList(title: "People", people: people)) {
                        moreCell
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func personCell(_ person: Person) -> some View {
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

    private var moreCell: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                Text("+\(hiddenCount)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: profileSize, height: profileSize)

            Text("More")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: itemWidth)
        }
    }
}

#Preview {
    NavigationStack {
        SearchPeopleStrip(people: Person.previewTeam, inlineCount: 3)
            .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

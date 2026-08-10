//
//  CastPersonList.swift
//  MovieTracker
//

import SwiftUI

/// The tappable list of people (rows + separators) used by every cast category.
struct CastPersonList: View {
    let people: [Person]

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                NavigationLink(value: person) {
                    HStack(spacing: 8) {
                        PersonRow(person: person)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < people.count - 1 {
                    CastRowSeparator()
                }
            }
        }
    }
}

/// The inset hairline between cast rows.
struct CastRowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(height: 0.5)
            .padding(.leading, 72)
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            CastPersonList(people: Person.previewTeam.filter { $0.type == .Cast })
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

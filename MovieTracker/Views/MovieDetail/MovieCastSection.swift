//
//  MovieCastSection.swift
//  MovieTracker
//

import SwiftUI

/// The Cast & Crew list on the movie detail screen: up to ten members, each a
/// navigation row to the person's detail.
struct MovieCastSection: View {
    let cast: [Person]

    var body: some View {
        if !cast.isEmpty {
            SectionHeader(title: "Cast & Crew")
            let members = Array(cast.prefix(10))
            LazyVStack(spacing: 0) {
                ForEach(Array(members.enumerated()), id: \.element.id) { index, person in
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

                    if index < members.count - 1 {
                        // Inset to start under the name, past the avatar.
                        Rectangle()
                            .fill(Color.appSeparator)
                            .frame(height: 0.5)
                            .padding(.leading, 72)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            MovieCastSection(cast: Movie.preview.team)
        }
        .movieTrackerDestinations()
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

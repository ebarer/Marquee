//
//  CastPersonList.swift
//  MovieTracker
//

import SwiftUI

/// The tappable list of people (rows + separators) used by every cast category.
struct CastPersonList: View {
    let people: [Person]
    var showsEpisodeCounts = false

    var body: some View {
        LazyVStack(spacing: 0) {
            CastPersonRows(people: people, showsEpisodeCounts: showsEpisodeCounts)
        }
    }
}

/// A nested `LazyVStack` builds every row as soon as its parent reaches it, so a caller with one uses this.
struct CastPersonRows: View {
    let people: [Person]
    var showsEpisodeCounts = false

    var body: some View {
        ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
            CastPersonRow(person: person, showsEpisodeCount: showsEpisodeCounts)
            if index < people.count - 1 {
                CastRowSeparator()
            }
        }
    }
}

/// One tappable person.
struct CastPersonRow: View {
    let person: Person
    var showsEpisodeCount = false
    var episodes: ShowEpisodeCredits?
    var imageSize: CGFloat = 44

    var body: some View {
        if let episodes {
            link(to: ShowCreditDestination.episodes(episodes))
        } else {
            link(to: person)
        }
    }

    private func link<Value: Hashable>(to value: Value) -> some View {
        NavigationLink(value: value) {
            HStack(spacing: 8) {
                PersonRow(person: person, showsEpisodeCount: showsEpisodeCount,
                          imageSize: imageSize)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.rowPress)
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

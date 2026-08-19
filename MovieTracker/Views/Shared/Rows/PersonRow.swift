//
//  PersonRow.swift
//  MovieTracker
//

import SwiftUI

struct PersonRow: View {
    let person: Person
    var showRole = true
    /// Show how many episodes they are in, where the credit carries a count (TV).
    var showsEpisodeCount = false
    /// The portrait's size. A row heading a list of episode stills passes their width, so its
    /// text lines up with theirs.
    var imageSize: CGFloat = 44

    var body: some View {
        HStack(spacing: 12) {
            ProfileImage(url: person.profileURL())
                .frame(width: imageSize, height: imageSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.body)
                    .foregroundStyle(.white)

                if showRole, let role = person.role, !role.isEmpty {
                    Text(role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if showsEpisodeCount, let count = person.episodeCount, count > 0 {
                    Text(EpisodeCredit.episodeCountLabel(count))
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PersonRow(person: .preview)
        .padding()
        .background(Color.appBackground)
}

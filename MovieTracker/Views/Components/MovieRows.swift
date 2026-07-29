//
//  MovieRows.swift
//  MovieTracker
//
//  Reusable SwiftUI row/card views replacing the storyboard cells
//  (MovieCollectionViewCell, MovieTableViewCell, PersonTableViewCell).
//

import SwiftUI

/// Grid card: poster above the title. Replaces `MovieCollectionViewCell`.
struct MoviePosterCard: View {
    let movie: Movie

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterImage(url: movie.posterURL(.w342))
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(movie.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// List row: poster beside title + release date. Replaces `MovieTableViewCell`.
struct MovieRow: View {
    let movie: Movie

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: movie.posterURL(.w185))
                .frame(width: 55, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let releaseDate = movie.releaseDate {
                    Text(releaseDate.toString())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

/// List row: circular profile beside name + role. Replaces `PersonTableViewCell`.
struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            ProfileImage(url: person.profileURL())
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.body)
                    .foregroundStyle(.white)

                if let role = person.role, !role.isEmpty {
                    Text(role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

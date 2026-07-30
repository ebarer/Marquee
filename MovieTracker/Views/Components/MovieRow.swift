//
//  MovieRow.swift
//  MovieTracker
//
//  List row: poster beside title + release date. Replaces `MovieTableViewCell`.
//

import SwiftUI

struct MovieRow: View {
    let movie: Movie
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: movie.posterURL(.w185))
                .frame(width: 55, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.body)
                    .lineLimit(2)

                if let displayedSubtitle {
                    Text(displayedSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    private var displayedSubtitle: String? {
        subtitle ?? movie.releaseDate?.toString()
    }
}

#Preview {
    MovieRow(movie: .preview)
}

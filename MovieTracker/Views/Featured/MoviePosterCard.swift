//
//  MoviePosterCard.swift
//  MovieTracker
//
//  Grid card: poster above a centered title. Replaces `MovieCollectionViewCell`.
//

import SwiftUI

struct MoviePosterCard: View {
    let movie: Movie
    /// Number of lines reserved for the title. Narrow layouts (e.g. the
    /// "Known For" strip) need more lines to avoid truncating long titles.
    var titleLineLimit: Int = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterImage(url: movie.posterURL(.w342))
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(movie.title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineLimit(titleLineLimit, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

#Preview {
    MoviePosterCard(movie: .preview)
        .frame(width: 120)
        .padding()
        .background(Color.appBackground)
}

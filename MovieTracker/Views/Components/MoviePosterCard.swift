//
//  MoviePosterCard.swift
//  MovieTracker
//
//  Grid card: poster above a centered title. Replaces `MovieCollectionViewCell`.
//

import SwiftUI

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
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineLimit(2, reservesSpace: true)
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

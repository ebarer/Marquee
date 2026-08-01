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
    /// Whether the title always reserves `titleLineLimit` lines of height. On
    /// keeps posters aligned across a grid; off lets the title hug its content
    /// so anything below it (e.g. a year caption) sits directly beneath.
    var reservesTitleSpace: Bool = true
    /// When set, the poster is laid out at this exact width (height = 3:2 of it).
    /// Single-row strips use this so the poster never shrinks to share vertical
    /// space with a taller title — keeping posters a uniform size and title tops
    /// aligned while their bottoms stay ragged.
    var posterWidth: CGFloat? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            poster

            Text(movie.title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineLimit(titleLineLimit, reservesSpace: reservesTitleSpace)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    /// The poster image. Fixed-size when `posterWidth` is given, otherwise
    /// aspect-fit to fill the card's width (the grid layout).
    @ViewBuilder
    private var poster: some View {
        if let posterWidth {
            PosterImage(url: movie.posterURL(.w342))
                .frame(width: posterWidth, height: posterWidth * 3.0 / 2.0)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            PosterImage(url: movie.posterURL(.w342))
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    MoviePosterCard(movie: .preview)
        .frame(width: 120)
        .padding()
        .background(Color.appBackground)
}

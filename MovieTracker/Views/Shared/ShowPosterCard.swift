//
//  ShowPosterCard.swift
//  MovieTracker
//

import SwiftUI

/// A show poster card mirroring `MoviePosterCard`, with the season count (gray)
/// beneath the name so a grid tile reads clearly as a series. The air year stands
/// in until the lazily-fetched count arrives.
struct ShowPosterCard: View {
    let show: Show
    var titleLineLimit: Int = 2
    var reservesTitleSpace: Bool = true
    var posterWidth: CGFloat? = nil

    var body: some View {
        VStack(spacing: 6) {
            poster

            Text(show.name)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineLimit(titleLineLimit, reservesSpace: reservesTitleSpace)
                .frame(maxWidth: .infinity, alignment: .center)

            ShowSeasonCountText(show: show,
                                placeholder: show.year.map(String.init),
                                font: .caption2)
        }
    }

    @ViewBuilder
    private var poster: some View {
        if let posterWidth {
            PosterImage(url: show.posterURL(.w342))
                .frame(width: posterWidth, height: posterWidth * 3.0 / 2.0)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            PosterImage(url: show.posterURL(.w342))
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    HStack(alignment: .top, spacing: 16) {
        ShowPosterCard(show: .preview, posterWidth: 110)
        ShowPosterCard(show: Show.previewList[1], posterWidth: 110)
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

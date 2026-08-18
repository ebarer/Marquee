//
//  PosterImage.swift
//  MovieTracker
//

import SwiftUI

/// A movie poster that fills its frame, with a film-icon placeholder.

struct PosterImage: View {
    let url: URL?

    var body: some View {
        RemoteImage(url: url) {
            ZStack {
                Color.appSeparator
                Image(systemName: "film")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension View {
    /// The hairline every poster carries, lifting its edge off the background. Pass the same
    /// radius the poster is clipped to.
    func posterBorder(cornerRadius: CGFloat) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach([Movie.preview, Movie.previewList[1]]) { movie in
            PosterImage(url: movie.posterURL(.w342))
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .frame(width: 140)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .posterBorder(cornerRadius: 8)
        }
        PosterImage(url: nil)
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .frame(width: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .posterBorder(cornerRadius: 8)
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

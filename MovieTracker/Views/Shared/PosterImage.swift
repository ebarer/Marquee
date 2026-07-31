//
//  PosterImage.swift
//  MovieTracker
//
//  A movie poster / backdrop image that fills its frame, with a placeholder.
//  On iOS 27 AsyncImage applies HTTP caching automatically, so posters are not
//  re-downloaded when scrolling back.
//

import SwiftUI

struct PosterImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Color.appSeparator
                Image(systemName: "film")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PosterImage(url: nil)
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .frame(width: 140)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
        .background(Color.appBackground)
}

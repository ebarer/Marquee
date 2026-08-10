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

#Preview {
    PosterImage(url: nil)
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .frame(width: 140)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
        .background(Color.appBackground)
}

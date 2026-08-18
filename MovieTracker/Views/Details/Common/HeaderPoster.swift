//
//  HeaderPoster.swift
//  MovieTracker
//

import SwiftUI

/// A detail header's poster thumbnail, tapping to morph into ``PosterDetailView``. Changing
/// `identity` (the show header passes the season poster path) crossfades the art.
struct HeaderPoster: View {
    let thumbnailURL: URL?
    let fullURL: URL?
    let tint: Color
    let zoomID: Int
    var identity: String? = nil
    let width: CGFloat
    let height: CGFloat

    @Namespace private var zoomNamespace
    @State private var showPoster = false

    var body: some View {
        PosterImage(url: thumbnailURL)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .posterBorder(cornerRadius: 6)
            .id(identity)
            .transition(.opacity)
            .matchedTransitionSource(id: zoomID, in: zoomNamespace)
            .onTapGesture { showPoster = true }
            .fullScreenCover(isPresented: $showPoster) {
                // The zoom transition lives inside PosterDetailView, so the poster morphs
                // into the enlarged image rather than the whole screen.
                PosterDetailView(imageURL: fullURL, tint: tint,
                                 zoomSourceID: zoomID, zoomNamespace: zoomNamespace)
            }
    }
}

#Preview {
    HeaderPoster(thumbnailURL: Movie.preview.posterURL(.w342),
                 fullURL: Movie.preview.posterURL(.orig),
                 tint: .appAccent, zoomID: Movie.preview.id,
                 width: 100, height: 150)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}

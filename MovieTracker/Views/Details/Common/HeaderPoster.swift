//
//  HeaderPoster.swift
//  MovieTracker
//

import SwiftUI

/// The rounded poster thumbnail in a detail header that taps to morph into the full-screen
/// ``PosterDetailView``. It owns the zoom namespace and cover so callers just supply the
/// artwork. `identity` gives the poster a new identity when it changes (the show header uses
/// the season poster path) so swapping seasons crossfades the art.
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
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
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

//
//  PosterSymbolBadge.swift
//  MovieTracker
//

import SwiftUI

/// A dark top-trailing corner gradient behind an SF Symbol, so any symbol laid over
/// poster art stays legible. Shared by the browse status badges and the Watched-list
/// partial-season mark.
struct PosterSymbolBadge: View {
    let symbol: String
    var cornerRadius: CGFloat = 8
    var pointSize: CGFloat = 18
    var padding: CGFloat = 7
    var verticalNudge: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            RadialGradient(
                gradient: Gradient(colors: [.black.opacity(0.55), .clear]),
                center: .topTrailing,
                startRadius: 0,
                endRadius: max(geo.size.width, geo.size.height) * 0.6
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(alignment: .topTrailing) {
            Image(systemName: symbol)
                .font(.system(size: pointSize, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 1.5, y: 0.5)
                .padding(padding)
                .offset(y: verticalNudge)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    PosterImage(url: Movie.preview.posterURL(.w342))
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay { PosterSymbolBadge(symbol: "circle.tophalf.filled") }
        .frame(width: 130)
        .padding()
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}

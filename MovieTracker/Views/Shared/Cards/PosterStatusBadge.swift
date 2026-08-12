//
//  PosterStatusBadge.swift
//  MovieTracker
//

import SwiftUI

/// A `PosterStatus` drawn as a corner badge, sized for the host artwork via `scale`.
struct PosterStatusBadge: View {
    let status: PosterStatus
    var cornerRadius: CGFloat = 8
    var scale: CGFloat = 1

    var body: some View {
        PosterSymbolBadge(symbol: status.symbol, cornerRadius: cornerRadius,
                          pointSize: status.pointSize * scale, padding: 7 * scale,
                          verticalNudge: status.verticalNudge * scale)
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach([PosterStatus.watched, .partial, .watchList], id: \.symbol) { status in
            PosterImage(url: Movie.preview.posterURL(.w342))
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay { PosterStatusBadge(status: status) }
        }
    }
    .frame(width: 340)
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

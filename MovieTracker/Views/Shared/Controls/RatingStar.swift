//
//  RatingStar.swift
//  MovieTracker
//

import SwiftUI

/// A single star filled left-to-right by `fraction`, the visual unit of `StarRating`.
struct RatingStar: View {
    let fraction: Double
    let tint: Color
    var size: CGFloat = 20
    var symbolScale: CGFloat = 0.75
    var emptyStyle: HierarchicalShapeStyle = .secondary

    var body: some View {
        Image(systemName: "star")
            .foregroundStyle(emptyStyle)
            .overlay(alignment: .leading) {
                Image(systemName: "star.fill")
                    .foregroundStyle(tint)
                    .mask(alignment: .leading) {
                        Rectangle().scale(x: fraction, y: 1, anchor: .leading)
                    }
            }
            .font(.system(size: size * symbolScale))
            .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 3) {
        RatingStar(fraction: 1, tint: .appAccent)
        RatingStar(fraction: 0.5, tint: .appAccent)
        RatingStar(fraction: 0, tint: .appAccent)
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

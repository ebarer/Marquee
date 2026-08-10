//
//  RatingStar.swift
//  MovieTracker
//

import SwiftUI

/// A single star filled left-to-right by `fraction` (0…1) — the visual unit of ``StarRating``.
struct RatingStar: View {
    let fraction: Double
    let tint: Color
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: "star")
            .foregroundStyle(.secondary)
            .overlay(alignment: .leading) {
                Image(systemName: "star.fill")
                    .foregroundStyle(tint)
                    .mask(alignment: .leading) {
                        Rectangle().scale(x: fraction, y: 1, anchor: .leading)
                    }
            }
            .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 3) {
        RatingStar(fraction: 1, tint: .appAccent)
        RatingStar(fraction: 0.5, tint: .appAccent)
        RatingStar(fraction: 0, tint: .appAccent)
    }
    .font(.system(size: 15))
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

//
//  StarRating.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Five stars bound to a title's personal rating. Tap for whole stars, sweep for
/// half-star precision; tapping the current rating clears it.
struct StarRating: View {
    let movie: Movie
    let tint: Color

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @State private var rating: Double
    /// The rating when the gesture began, so a stationary tap toggles against the
    /// pre-gesture value rather than the one `onChanged` previewed.
    @State private var dragStartRating: Double?

    private let starSize: CGFloat = 20
    private let spacing: CGFloat = 3

    init(movie: Movie, rating: Double, tint: Color) {
        self.movie = movie
        self.tint = tint
        _rating = State(initialValue: rating)
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { index in
                star(filledBy: fillFraction(for: index))
            }
        }
        .font(.system(size: 15))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStartRating == nil { dragStartRating = rating }
                    rating = halfStars(at: value.location.x)
                }
                .onEnded { value in
                    if value.translation.width == 0 {
                        // Stationary tap: a whole star, or clear if already selected.
                        let whole = wholeStars(at: value.location.x)
                        rating = (whole == dragStartRating) ? 0 : whole
                    } else {
                        rating = halfStars(at: value.location.x)
                    }
                    store?.setRating(rating == 0 ? nil : rating, for: movie)
                    dragStartRating = nil
                }
        )
    }

    private func star(filledBy fraction: Double) -> some View {
        Image(systemName: "star")
            .foregroundStyle(.secondary)
            .overlay(alignment: .leading) {
                Image(systemName: "star.fill")
                    .foregroundStyle(tint)
                    .mask(alignment: .leading) {
                        Rectangle().scale(x: fraction, y: 1, anchor: .leading)
                    }
            }
            .frame(width: starSize, height: starSize)
    }

    private func fillFraction(for index: Int) -> Double {
        min(1, max(0, rating - Double(index - 1)))
    }

    private func wholeStars(at x: CGFloat) -> Double {
        guard x >= 0 else { return 0 }
        let slot = starSize + spacing
        return min(5, Double(Int(x / slot) + 1))
    }

    /// The half-step value under a horizontal offset (for sweeps): the left half of
    /// a star gives x.5, the right half a whole star.
    private func halfStars(at x: CGFloat) -> Double {
        guard x >= 0 else { return 0 }
        let slot = starSize + spacing
        let index = Int(x / slot)
        let within = (x - Double(index) * slot) / starSize
        let value = Double(index) + (within <= 0.5 ? 0.5 : 1.0)
        return min(5, value)
    }
}

#Preview("Rated (4 stars)") {
    StarRating(movie: Movie.previewList[1], rating: 4, tint: .appAccent)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}

#Preview("Unrated") {
    StarRating(movie: .preview, rating: 0, tint: .yellow)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}

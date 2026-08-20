//
//  StarRating.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Five stars showing a title's personal rating; the `display` form is the same stars, inert.
struct StarRating: View {
    private enum Commit {
        case key(MediaKey)
        case closure((Double?) -> Void)
    }

    private let rating: Double
    private let commit: Commit?
    private let tint: Color
    private let starSize: CGFloat
    private let spacing: CGFloat

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @State private var draft: Double?
    // The rating when the gesture began, so a stationary tap toggles against the
    // pre-gesture value rather than the one `onChanged` previewed.
    @State private var dragStartRating: Double?

    init(key: MediaKey, rating: Double, tint: Color) {
        self.rating = rating
        self.commit = .key(key)
        self.tint = tint
        self.starSize = 20
        self.spacing = 3
    }

    init(movie: Movie, rating: Double, tint: Color) {
        self.init(key: movie.mediaKey, rating: rating, tint: tint)
    }

    init(rating: Double, tint: Color, onCommit: @escaping (Double?) -> Void) {
        self.rating = rating
        self.commit = .closure(onCommit)
        self.tint = tint
        self.starSize = 20
        self.spacing = 3
    }

    init(display rating: Double, size: CGFloat = 13, spacing: CGFloat = 2, tint: Color = .appAccent) {
        self.rating = rating
        self.commit = nil
        self.tint = tint
        self.starSize = size
        self.spacing = spacing
    }

    private var isEditable: Bool { commit != nil }
    private var displayed: Double { draft ?? rating }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { index in
                RatingStar(fraction: fillFraction(for: index), tint: tint, size: starSize,
                           symbolScale: isEditable ? 0.75 : 0.85,
                           emptyStyle: isEditable ? .secondary : .tertiary)
            }
        }
        .contentShape(Rectangle())
        .gesture(ratingGesture, including: isEditable ? .all : .none)
    }

    private var ratingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartRating == nil { dragStartRating = displayed }
                draft = halfStars(at: value.location.x)
            }
            .onEnded { value in
                let newRating: Double
                if value.translation.width == 0 {
                    // Stationary tap: a whole star, or clear if already selected.
                    let whole = wholeStars(at: value.location.x)
                    newRating = (whole == dragStartRating) ? 0 : whole
                } else {
                    newRating = halfStars(at: value.location.x)
                }
                draft = newRating
                persist(newRating == 0 ? nil : newRating)
                dragStartRating = nil
            }
    }

    private func persist(_ value: Double?) {
        switch commit {
        case .key(let key): store?.setRating(value, forKey: key)
        case .closure(let onCommit): onCommit(value)
        case nil: break
        }
    }

    private func fillFraction(for index: Int) -> Double {
        min(1, max(0, displayed - Double(index - 1)))
    }

    private func wholeStars(at x: CGFloat) -> Double {
        guard x >= 0 else { return 0 }
        let slot = starSize + spacing
        return min(5, Double(Int(x / slot) + 1))
    }

    private func halfStars(at x: CGFloat) -> Double {
        guard x >= 0 else { return 0 }
        let slot = starSize + spacing
        let index = Int(x / slot)
        let within = (x - Double(index) * slot) / starSize
        let value = Double(index) + (within <= 0.5 ? 0.5 : 1.0)
        return min(5, value)
    }
}

#Preview("Editable") {
    VStack(spacing: 24) {
        StarRating(movie: Movie.previewList[1], rating: 4, tint: .appAccent)
        StarRating(movie: .preview, rating: 0, tint: .yellow)
    }
    .padding()
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Display") {
    VStack(alignment: .leading, spacing: 12) {
        StarRating(display: 5)
        StarRating(display: 3.5)
        StarRating(display: 1, size: 15, tint: ListDestination.watchedColor)
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

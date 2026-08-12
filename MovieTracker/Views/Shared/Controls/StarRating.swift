//
//  StarRating.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Five stars showing a title's personal rating. Editable forms take a tap for whole stars
/// and a sweep for halves; the `display` form is the same stars, inert, for rows and headers.
struct StarRating: View {
    /// Where a committed rating goes; `nil` for the read-only display.
    private enum Commit {
        case key(MediaKey)
        /// Per-season ratings aren't keyed by `MediaKey`, so the caller persists them.
        case closure((Double?) -> Void)
    }

    private let rating: Double
    private let commit: Commit?
    private let tint: Color
    private let starSize: CGFloat
    private let spacing: CGFloat

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    /// The value the user has set here; `nil` until they interact, so a read-only
    /// display always tracks the rating passed in.
    @State private var draft: Double?
    // The rating when the gesture began, so a stationary tap toggles against the
    // pre-gesture value rather than the one `onChanged` previewed.
    @State private var dragStartRating: Double?

    /// Editable, writing through the `MediaItem` for `key`.
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

    /// Editable with caller-driven persistence (e.g. a season).
    init(rating: Double, tint: Color, onCommit: @escaping (Double?) -> Void) {
        self.rating = rating
        self.commit = .closure(onCommit)
        self.tint = tint
        self.starSize = 20
        self.spacing = 3
    }

    /// Read-only stars sized for a row or section header.
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

// Editable: rated (4 stars) and unrated.
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

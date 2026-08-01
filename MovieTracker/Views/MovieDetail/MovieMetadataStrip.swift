//
//  MovieMetadataStrip.swift
//  MovieTracker
//
//  Horizontal strip of movie metadata cells (rating, credit clips, TMDB score,
//  genre) shown on the movie detail screen.
//

import SwiftUI
import SwiftData

struct MovieMetadataStrip: View {
    let movie: Movie
    /// The Watched list, if available. When the movie is on it, a tappable
    /// "MY RATING" cell is shown so the user can rate the movie themselves.
    var watchedList: MovieList? = nil
    var context: ModelContext? = nil
    /// The movie's accent color, used to fill the rating stars.
    var tint: Color = .appAccent
    /// Whether the movie is on the Watched list; drives the MY RATING cell's
    /// animated appearance. Passed in (rather than derived) so a watched-status
    /// change animates smoothly.
    var isWatched: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            hairline
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    // The user's own rating leads the strip for watched movies,
                    // sliding in from the leading edge as the status changes.
                    if let watchedList, let context, isWatched {
                        HStack(alignment: .top, spacing: 0) {
                            cell(header: "MY RATING") {
                                StarRating(movieID: movie.id, list: watchedList, context: context, tint: tint)
                            }
                            divider
                        }
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                    cell(header: "RATING", minWidth: 60) {
                        if let cert = movie.certification, let image = UIImage(named: "Cert-\(cert)") {
                            // A definite frame (not just a max) so the resizable
                            // badge can't expand to its native width under the
                            // cell's `fixedSize`; scaledToFit letterboxes narrow
                            // certs (e.g. "R") within it.
                            Image(uiImage: image)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 24)
                                .foregroundStyle(.white)
                        } else {
                            valueText("N/A")
                        }
                    }
                    divider
                    cell(header: "CREDIT CLIPS") { valueText(movie.bonusString) }
                    divider
                    cell(header: "TMDB.org") { tmdbScore.multilineTextAlignment(.center) }
                    divider
                    cell(header: "GENRE", minWidth: 90) { valueText(movie.genresString) }
                }
                .animation(.snappy, value: isWatched)
            }
            // Always allow elastic scrolling, even when the cells fit within the width.
            .scrollBounceBehavior(.always, axes: .horizontal)
            hairline
        }
    }

    /// The TMDB score, with the "/ 5" suffix dimmed so the number itself stands
    /// out. Whole scores drop the decimal (4.0 → "4").
    private var tmdbScore: Text {
        guard let rating = movie.rating, rating > 0 else {
            return Text("N/A")
        }
        // Round to the one-decimal precision we display first, so a score that
        // rounds to a whole number (e.g. 3.95 → 4.0) drops the decimal too.
        let score = (rating / 2 * 10).rounded() / 10
        let formatted = score == score.rounded()
            ? String(format: "%.0f", score)
            : String(format: "%.1f", score)
        return Text("\(formatted)\(Text(" / 5").foregroundColor(.secondary))")
    }

    // A column sized to its content: title label at the top, value beneath it.
    // The horizontal padding matches the screen's content margin so the first
    // cell's content lines up with the poster/description (and the last cell's
    // trailing edge mirrors it).
    private func cell<Content: View>(header: String, minWidth: CGFloat = 44,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            Text(header)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .fixedSize()
        .frame(minWidth: minWidth, alignment: .top)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func valueText(_ text: String) -> some View {
        Text(text).multilineTextAlignment(.center)
    }

    // Full-width top/bottom rule.
    private var hairline: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(height: 0.5)
    }

    // Vertical rule between columns. Inset top/bottom by the same amount as the cell's vertical
    // text padding so it doesn't touch the top/bottom hairlines.
    private var divider: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(width: 0.5)
            .frame(maxHeight: .infinity)
            .padding(.vertical, 14)
    }
}

/// Five stars that read and write the user's personal rating on a movie's list
/// entry. Tap a star for a whole-star score; sweep across the row for half-star
/// precision (a half-filled star). Tapping the current rating again clears it.
private struct StarRating: View {
    let movieID: Int
    let list: MovieList
    let context: ModelContext
    let tint: Color
    /// In stars, 0.5-step (0 = unrated).
    @State private var rating: Double
    /// The rating when the current gesture began, so a stationary tap can toggle
    /// against the pre-gesture value (not the one `onChanged` just previewed).
    @State private var dragStartRating: Double?

    private let starSize: CGFloat = 20
    private let spacing: CGFloat = 3

    init(movieID: Int, list: MovieList, context: ModelContext, tint: Color) {
        self.movieID = movieID
        self.list = list
        self.context = context
        self.tint = tint
        _rating = State(initialValue: WatchListStore.rating(for: movieID, in: list) ?? 0)
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
                    // Live half-step preview while sweeping.
                    rating = halfStars(at: value.location.x)
                }
                .onEnded { value in
                    if value.translation.width == 0 {
                        // A stationary tap: a whole star, or clear if it's the
                        // one already selected.
                        let whole = wholeStars(at: value.location.x)
                        rating = (whole == dragStartRating) ? 0 : whole
                    } else {
                        rating = halfStars(at: value.location.x)
                    }
                    WatchListStore.setRating(rating == 0 ? nil : rating, for: movieID, in: list)
                    dragStartRating = nil
                }
        )
    }

    /// A single star showing an outline with `fraction` (0, 0.5, or 1) of its
    /// width filled in the tint color.
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

    /// How much of star `index` (1–5) is filled by the current rating: 1 full,
    /// 0.5 half, 0 empty.
    private func fillFraction(for index: Int) -> Double {
        min(1, max(0, rating - Double(index - 1)))
    }

    /// The whole-star value under a horizontal offset (for taps).
    private func wholeStars(at x: CGFloat) -> Double {
        guard x >= 0 else { return 0 }
        let slot = starSize + spacing
        return min(5, Double(Int(x / slot) + 1))
    }

    /// The half-step value under a horizontal offset (for sweeps): the left half
    /// of a star gives x.5, the right half a whole star.
    private func halfStars(at x: CGFloat) -> Double {
        guard x >= 0 else { return 0 }
        let slot = starSize + spacing
        let index = Int(x / slot)                      // 0-based star under the finger
        let within = (x - Double(index) * slot) / starSize
        let value = Double(index) + (within <= 0.5 ? 0.5 : 1.0)
        return min(5, value)
    }
}

#Preview {
    MovieMetadataStrip(movie: .preview)
        .background(Color.appBackground)
}

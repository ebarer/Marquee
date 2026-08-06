//
//  MovieRow.swift
//  MovieTracker
//
//  Presentational list row: poster beside title, subtitle, and optional rating.
//

import SwiftUI

struct MovieRow: View {
    let movie: Movie
    var subtitle: String? = nil
    /// An optional secondary line below the subtitle, e.g. the person's role in
    /// this movie when shown in a filmography.
    var role: String? = nil
    /// When false, the row shows no subtitle line at all — no explicit subtitle
    /// and no release-date fallback.
    var showsSubtitle: Bool = true
    /// An optional duration line (e.g. "2 hr 8 min") shown beneath the subtitle,
    /// formatted like the movie detail page.
    var duration: String? = nil
    /// The user's personal rating in stars (0.5-step); when set and > 0, a compact
    /// read-only star row appears beneath the subtitle.
    var rating: Double? = nil
    /// Fill color for the rating stars.
    var ratingTint: Color = .appAccent
    /// When set, a watched / to-be-watched badge is overlaid on the poster. Takes
    /// precedence over `derivesStatus` so a caller can force (or suppress) the badge.
    var status: PosterStatus? = nil
    /// When true and no explicit `status` is given, the row derives its own badge
    /// from the environment's persistence store — used where the caller can't know
    /// list membership up front (search results, filmographies).
    var derivesStatus: Bool = false

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: movie.posterURL(.w185))
                .frame(width: 51, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay { badge }
                // Slightly shorter poster (3pt top/bottom) so rows breathe and
                // the first result clears the scope bar.
                .padding(.vertical, 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.body)
                    .lineLimit(2)

                if showsSubtitle, let displayedSubtitle {
                    Text(displayedSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let role, !role.isEmpty {
                    Text(role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let duration, !duration.isEmpty {
                    Text(duration)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let rating, rating > 0 {
                    RatingStars(rating: rating, tint: ratingTint)
                        .padding(.top, 1)
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var badge: some View {
        if let effectiveStatus {
            PosterStatusBadge(status: effectiveStatus, cornerRadius: 6, scale: 0.72)
                .transition(.opacity)
        }
    }

    /// Watched wins over the Watch List (the two are mutually exclusive in practice).
    private var effectiveStatus: PosterStatus? {
        if let status { return status }
        guard derivesStatus, let store else { return nil }
        _ = store.revision   // observe persisted changes so the badge refreshes live
        if store.isWatched(movie) { return .watched }
        if store.isInWatchList(movie) { return .watchList }
        return nil
    }

    private var displayedSubtitle: String? {
        subtitle ?? movie.releaseDate?.toString()
    }
}

/// A compact, read-only five-star display of a personal rating (0.5-step). Mirrors
/// the interactive star rendering on the movie detail screen, shrunk to fit a row.
struct RatingStars: View {
    /// In stars, 0.5-step (0 = unrated).
    let rating: Double
    var starSize: CGFloat = 13
    var spacing: CGFloat = 2
    var tint: Color = .appAccent

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { index in
                star(filledBy: min(1, max(0, rating - Double(index - 1))))
            }
        }
        .font(.system(size: starSize * 0.85))
    }

    /// A single star: a dim outline with `fraction` (0, 0.5, or 1) of its width
    /// filled in the tint color.
    private func star(filledBy fraction: Double) -> some View {
        Image(systemName: "star")
            .foregroundStyle(.tertiary)
            .overlay(alignment: .leading) {
                Image(systemName: "star.fill")
                    .foregroundStyle(tint)
                    .mask(alignment: .leading) {
                        Rectangle().scale(x: fraction, y: 1, anchor: .leading)
                    }
            }
            .frame(width: starSize, height: starSize)
    }
}

#Preview {
    List {
        MovieRow(movie: .preview, status: .watched)
        MovieRow(movie: .preview, status: .watchList)
        MovieRow(movie: .preview)
    }
    .listStyle(.plain)
    .preferredColorScheme(.dark)
}

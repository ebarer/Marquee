//
//  MoviePosterCard.swift
//  MovieTracker
//
//  Grid card: poster above a centered title. Replaces `MovieCollectionViewCell`.
//

import SwiftUI

struct MoviePosterCard: View {
    let movie: Movie
    /// Number of lines reserved for the title. Narrow layouts (e.g. the
    /// "Known For" strip) need more lines to avoid truncating long titles.
    var titleLineLimit: Int = 2
    /// Whether the title always reserves `titleLineLimit` lines of height. On
    /// keeps posters aligned across a grid; off lets the title hug its content
    /// so anything below it (e.g. a year caption) sits directly beneath.
    var reservesTitleSpace: Bool = true
    /// When set, the poster is laid out at this exact width (height = 3:2 of it).
    /// Single-row strips use this so the poster never shrinks to share vertical
    /// space with a taller title — keeping posters a uniform size and title tops
    /// aligned while their bottoms stay ragged.
    var posterWidth: CGFloat? = nil

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    /// Watched wins over Watch List (the two are mutually exclusive in practice,
    /// since adding to the Watch List un-marks Watched).
    private var status: PosterStatus? {
        guard let store else { return nil }
        if store.isWatched(movie) { return .watched }
        if store.isInWatchList(movie) { return .watchList }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            poster

            Text(movie.title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineLimit(titleLineLimit, reservesSpace: reservesTitleSpace)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    /// The poster image. Fixed-size when `posterWidth` is given, otherwise
    /// aspect-fit to fill the card's width (the grid layout).
    @ViewBuilder
    private var poster: some View {
        if let posterWidth {
            PosterImage(url: movie.posterURL(.w342))
                .frame(width: posterWidth, height: posterWidth * 3.0 / 2.0)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay { badge }
        } else {
            PosterImage(url: movie.posterURL(.w342))
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay { badge }
        }
    }

    @ViewBuilder
    private var badge: some View {
        if let status {
            PosterStatusBadge(status: status)
                .transition(.opacity)
        }
    }
}

enum PosterStatus {
    case watched
    case watchList

    var symbol: String {
        switch self {
        case .watched: return "checkmark.circle.fill"
        case .watchList: return "bookmark.fill"
        }
    }

    var pointSize: CGFloat {
        switch self {
        case .watched: return 18
        case .watchList: return 15
        }
    }

    var verticalNudge: CGFloat {
        switch self {
        case .watched: return -1
        case .watchList: return 0
        }
    }
}

struct PosterStatusBadge: View {
    let status: PosterStatus
    var cornerRadius: CGFloat = 8

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
            Image(systemName: status.symbol)
                .font(.system(size: status.pointSize, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 1.5, y: 0.5)
                .padding(7)
                .offset(y: status.verticalNudge)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach([PosterStatus.watched, .watchList], id: \.symbol) { status in
            PosterImage(url: Movie.preview.posterURL(.w342))
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay { PosterStatusBadge(status: status) }
        }
    }
    .frame(width: 260)
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

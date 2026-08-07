//
//  MoviePosterCard.swift
//  MovieTracker
//

import SwiftUI

struct MoviePosterCard: View {
    let movie: Movie
    var titleLineLimit: Int = 2
    var reservesTitleSpace: Bool = true
    var posterWidth: CGFloat? = nil

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    private var status: PosterStatus? {
        guard let store else { return nil }
        _ = store.revision   // observe persisted changes so the badge refreshes live
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
    var scale: CGFloat = 1

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
                .font(.system(size: status.pointSize * scale, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 1.5, y: 0.5)
                .padding(7 * scale)
                .offset(y: status.verticalNudge * scale)
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

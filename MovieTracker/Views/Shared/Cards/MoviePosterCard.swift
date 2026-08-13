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

#Preview {
    HStack(spacing: 16) {
        MoviePosterCard(movie: .preview)
        MoviePosterCard(movie: Movie.previewList[1])
    }
    .frame(width: 260)
    .padding()
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

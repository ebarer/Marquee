//
//  ShowPosterCard.swift
//  MovieTracker
//

import SwiftUI

/// A show poster card mirroring `MoviePosterCard`, with the season count (gray)
/// beneath the name so a grid tile reads clearly as a series. The air year stands
/// in until the lazily-fetched count arrives.
struct ShowPosterCard: View {
    let show: Show
    var titleLineLimit: Int = 2
    var reservesTitleSpace: Bool = true
    var posterWidth: CGFloat? = nil

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    private var status: PosterStatus? {
        guard let store else { return nil }
        _ = store.revision   // observe persisted changes so the badge refreshes live
        if store.isShowWatchedCached(showID: show.id) { return .watched }
        if store.hasWatchedEpisodes(showID: show.id) { return .partial }
        if store.isInWatchList(show) { return .watchList }
        return nil
    }

    var body: some View {
        VStack(spacing: 6) {
            poster

            Text(show.name)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineLimit(titleLineLimit, reservesSpace: reservesTitleSpace)
                .frame(maxWidth: .infinity, alignment: .center)

            ShowSeasonCountText(show: show,
                                placeholder: show.year.map(String.init),
                                font: .caption2)
        }
    }

    @ViewBuilder
    private var poster: some View {
        if let posterWidth {
            PosterImage(url: show.posterURL(.w342))
                .frame(width: posterWidth, height: posterWidth * 3.0 / 2.0)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay { badge }
        } else {
            PosterImage(url: show.posterURL(.w342))
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
    HStack(alignment: .top, spacing: 16) {
        ShowPosterCard(show: .preview, posterWidth: 110)
        ShowPosterCard(show: Show.previewList[1], posterWidth: 110)
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

// Badges rendered directly (like MoviePosterCard's preview) — seeding a live store in a
// preview trips CloudKit's "No eligible connection".
#Preview("Status badges") {
    HStack(spacing: 16) {
        ForEach([PosterStatus.watched, .watchList], id: \.symbol) { status in
            PosterImage(url: Show.preview.posterURL(.w342))
                .frame(width: 110, height: 110 * 3.0 / 2.0)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay { PosterStatusBadge(status: status) }
        }
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

#Preview("Incomplete") {
    HStack(spacing: 16) {
        // Solid fills stand in for poster art so the corner gradient behind the
        // symbol is obvious even without a network image.
        Rectangle().fill(.orange)
            .frame(width: 51, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                PosterSymbolBadge(symbol: "circle.tophalf.filled",
                                  cornerRadius: 6, pointSize: 15, padding: 5)
            }
        Rectangle().fill(.white)
            .frame(width: 51, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                PosterSymbolBadge(symbol: "circle.tophalf.filled",
                                  cornerRadius: 6, pointSize: 15, padding: 5)
            }
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

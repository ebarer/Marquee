//
//  EpisodeRow.swift
//  MovieTracker
//

import SwiftUI

/// One episode row: still (with a corner watched-toggle), title/meta (``EpisodeRowText``),
/// and a trailing chevron. The whole row pushes the episode detail; the still's badge
/// toggles watched in place. Toggle state is owned by the parent.
struct EpisodeRow: View {
    let episode: Episode
    var isWatched: Bool
    var tint: Color = .appAccent
    var onToggleWatched: () -> Void

    // Matches the poster width in the Recommendations strip for column alignment.
    private static let stillWidth: CGFloat = 90

    var body: some View {
        DetailLink(value: episode) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggleWatched) {
                    PosterImage(url: episode.stillURL())
                        .frame(width: Self.stillWidth, height: Self.stillWidth * 9.0 / 16.0)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay { watchedBadge }
                }
                .disabled(!episode.hasAired)
                .accessibilityLabel(accessibilityLabel)

                HStack(alignment: .center, spacing: 8) {
                    EpisodeRowText(episode: episode, tint: tint)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .offset(y: -1.5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    /// Shares the poster status badges' gradient scrim (``PosterSymbolBadge``); the corner
    /// button above toggles it. Reuses the watched badge verbatim, showing a dimmed empty
    /// ring until the episode is watched — a dotted ring while it hasn't aired, where the
    /// toggle is inert.
    @ViewBuilder
    private var watchedBadge: some View {
        if isWatched {
            PosterStatusBadge(status: .watched, cornerRadius: 6)
        } else {
            PosterSymbolBadge(symbol: episode.hasAired ? "circle" : "circle.dotted", cornerRadius: 6)
                .opacity(0.85)
        }
    }

    private var accessibilityLabel: String {
        if !episode.hasAired { return "Episode hasn't aired yet" }
        return isWatched ? "Mark episode unwatched" : "Mark episode watched"
    }
}

#Preview {
    var upcoming = Episode.previewEpisodes[2]
    upcoming.airDate = Date().addingTimeInterval(60 * 60 * 24 * 14)

    return NavigationStack {
        VStack(spacing: 0) {
            EpisodeRow(episode: Episode.previewEpisodes[0], isWatched: true, onToggleWatched: {})
            EpisodeRow(episode: Episode.previewEpisodes[1], isWatched: false, onToggleWatched: {})
            EpisodeRow(episode: upcoming, isWatched: false, onToggleWatched: {})
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

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
        HStack(alignment: .top, spacing: 12) {
            // The still navigates; the corner toggle (a sibling on top) toggles watched.
            ZStack(alignment: .topTrailing) {
                DetailLink(value: episode) {
                    PosterImage(url: episode.stillURL())
                        .frame(width: Self.stillWidth, height: Self.stillWidth * 9.0 / 16.0)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay { watchedBadge }
                }
                .buttonStyle(.plain)

                // Only the corner is tappable; the rest of the still navigates.
                Button(action: onToggleWatched) { Color.clear }
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityLabel(isWatched ? "Mark episode unwatched" : "Mark episode watched")
            }

            DetailLink(value: episode) {
                HStack(alignment: .center, spacing: 8) {
                    EpisodeRowText(episode: episode, tint: tint)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Nudge up so the title top and bottom label align with the still's edges.
            .offset(y: -1.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// Shares the poster status badges' gradient scrim (``PosterSymbolBadge``); the corner
    /// button above toggles it. Reuses the watched badge verbatim, showing a dimmed empty
    /// ring until the episode is watched.
    @ViewBuilder
    private var watchedBadge: some View {
        if isWatched {
            PosterStatusBadge(status: .watched, cornerRadius: 6)
        } else {
            PosterSymbolBadge(symbol: "circle", cornerRadius: 6)
                .opacity(0.85)
        }
    }
}

#Preview {
    NavigationStack {
        VStack(spacing: 0) {
            EpisodeRow(episode: Episode.previewEpisodes[0], isWatched: true, onToggleWatched: {})
            EpisodeRow(episode: Episode.previewEpisodes[1], isWatched: false, onToggleWatched: {})
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

//
//  EpisodeRow.swift
//  MovieTracker
//

import SwiftUI

/// One episode row: still (with a corner watched-toggle), title, "SX, EY • air date"
/// in the show accent, duration + star rating, and a 2-line synopsis. The whole row
/// pushes the episode detail (trailing chevron); the still's badge toggles watched in
/// place. Toggle state is owned by the parent.
struct EpisodeRow: View {
    let episode: Episode
    var isWatched: Bool
    var tint: Color = .appAccent
    var onToggleWatched: () -> Void

    // Matches the poster width in the Recommendations strip for column alignment.
    private static let stillWidth: CGFloat = 90

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // The still navigates; the badge (a sibling on top) toggles watched.
            ZStack(alignment: .topTrailing) {
                DetailLink(value: episode) {
                    PosterImage(url: episode.stillURL())
                        .frame(width: Self.stillWidth, height: Self.stillWidth * 9.0 / 16.0)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                watchedBadge
            }

            DetailLink(value: episode) {
                HStack(alignment: .center, spacing: 8) {
                    textColumn
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(episode.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(codeAndDate)
                .font(.caption)
                .foregroundStyle(tint)

            if episode.duration != nil || (episode.rating ?? 0) > 0 {
                HStack(spacing: 5) {
                    if let duration = episode.duration {
                        Text(duration)
                    }
                    if let rating = episode.rating, rating > 0 {
                        // A small star acts as the interpunct between duration and score
                        // (score on the app's 5-point scale).
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                        Text(String(format: "%.1f", rating / 2))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let overview = episode.overview, !overview.isEmpty {
                Text(overview)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
            }
        }
    }

    private var codeAndDate: String {
        var text = "S\(episode.seasonNumber), E\(episode.episodeNumber)"
        if let date = episode.airDate?.toString() { text += "  •  \(date)" }
        return text
    }

    /// A corner toggle styled like the movie "watched" badge when on.
    private var watchedBadge: some View {
        Button(action: onToggleWatched) {
            Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isWatched ? .white : .white.opacity(0.85))
                .shadow(color: .black.opacity(0.5), radius: 2, y: 0.5)
                .padding(5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isWatched ? "Mark episode unwatched" : "Mark episode watched")
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

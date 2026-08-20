//
//  EpisodeRowText.swift
//  MovieTracker
//

import SwiftUI

/// The title / "SX, EY • air date" / duration + rating column of an ``EpisodeRow``.
struct EpisodeRowText: View {
    let episode: Episode
    var tint: Color = .appAccent
    var role: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(episode.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(codeAndDate)
                .font(.caption)
                .foregroundStyle(tint)

            if let role, !role.isEmpty {
                Text(role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if episode.duration != nil || (episode.rating ?? 0) > 0 {
                HStack(spacing: 5) {
                    if let duration = episode.duration {
                        Text(duration)
                    }
                    if let rating = episode.rating, rating > 0 {
                        // A small star acts as the interpunct between duration and score.
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                        Text(String(format: "%.1f", rating / 2))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var codeAndDate: String {
        var text = "S\(episode.seasonNumber), E\(episode.episodeNumber)"
        if let date = episode.airDate?.toString() { text += "  •  \(date)" }
        return text
    }
}

#Preview {
    EpisodeRowText(episode: Episode.previewEpisodes[0])
        .padding()
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}

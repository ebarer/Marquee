//
//  SeasonEpisodeList.swift
//  MovieTracker
//

import SwiftUI

/// The episode rows for a season, with separators between them.
struct SeasonEpisodeList: View {
    let episodes: [Episode]
    let watchedNumbers: Set<Int>
    var tint: Color = .appAccent
    /// Set by a person's episode list; see ``EpisodeRowText``.
    var role: String? = nil
    let onToggle: (Episode) -> Void

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(episodes.enumerated()), id: \.element.id) { index, episode in
                EpisodeRow(episode: episode,
                           isWatched: watchedNumbers.contains(episode.episodeNumber),
                           tint: tint,
                           role: role) {
                    onToggle(episode)
                }
                if index < episodes.count - 1 { rowSeparator }
            }
        }
    }

    private var rowSeparator: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            SeasonEpisodeList(episodes: Episode.previewEpisodes, watchedNumbers: [1], onToggle: { _ in })
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}

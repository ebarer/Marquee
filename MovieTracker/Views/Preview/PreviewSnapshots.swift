//
//  PreviewSnapshots.swift
//  MovieTracker
//

import Foundation
import SwiftData

extension MediaSnapshot {
    // A snapshot needs a real `PersistentIdentifier`, so each fixture inserts a throwaway model.
    @MainActor
    static func preview(id: Int, title: String, mediaType: MediaType = .movie,
                        posterPath: String? = "preview-poster",
                        season: Int? = nil, seasonWatched: Int? = nil, seasonTotal: Int? = nil,
                        nextEpisodeDate: Date? = nil, runtime: Int? = 120,
                        dateWatched: Date? = nil, userRating: Double? = nil) -> MediaSnapshot {
        let item = MediaItem(tmdbID: id, mediaType: mediaType, title: title)
        item.watchedAt = dateWatched
        item.userRating = userRating
        previewModelContainer.mainContext.insert(item)
        return MediaSnapshot(persistentID: item.persistentModelID, tmdbID: id,
                             mediaType: mediaType, title: title, posterPath: posterPath,
                             releaseDate: nil, sortDate: nil, seasonNumber: season,
                             seasonWatched: seasonWatched, seasonTotal: seasonTotal,
                             nextEpisodeDate: nextEpisodeDate, runtime: runtime,
                             dateWatched: dateWatched, userRating: userRating)
    }
}

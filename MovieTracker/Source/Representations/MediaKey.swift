//
//  MediaKey.swift
//  MovieTracker
//

import Foundation

/// A media-type-tagged key plus display snapshot that both `Movie` and `Show` produce,
/// letting the persistence layer (MediaItem / ListEntry / MediaList) store and dedupe
/// either kind with no schema change — both models already carry `mediaTypeRaw`, and the
/// composite (tmdbID, mediaType) is the dedup key.
struct MediaKey {
    let tmdbID: Int
    let mediaType: MediaType
    let title: String
    let posterPath: String?
    let releaseDate: Date?
    let runtime: Int?
    /// Timeline anchor for list sorting when it should differ from `releaseDate` (a show's
    /// most-recent air date vs. its premiere). Nil for movies — they sort by `releaseDate`.
    let sortDate: Date?
}

extension Movie {
    var mediaKey: MediaKey {
        MediaKey(tmdbID: id, mediaType: .movie, title: title, posterPath: poster,
                 releaseDate: releaseDate, runtime: runtime, sortDate: nil)
    }
}

extension Show {
    var mediaKey: MediaKey {
        MediaKey(tmdbID: id, mediaType: .tv, title: name, posterPath: poster,
                 releaseDate: firstAirDate, runtime: nil, sortDate: timelineDate)
    }
}

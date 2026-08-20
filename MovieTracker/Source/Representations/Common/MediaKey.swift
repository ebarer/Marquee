//
//  MediaKey.swift
//  MovieTracker
//

import Foundation

/// A type-tagged key plus display snapshot, so persistence can store and dedupe a movie or show alike.
struct MediaKey {
    let tmdbID: Int
    let mediaType: MediaType
    let title: String
    let posterPath: String?
    let releaseDate: Date?
    let runtime: Int?
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

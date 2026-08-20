//
//  ListEntry.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// A title's membership in one `MediaList`: a display snapshot, no personal facts.
@Model
final class ListEntry {
    var tmdbID: Int = 0
    var mediaTypeRaw: Int = MediaType.movie.rawValue
    var title: String = ""
    var posterPath: String?
    var releaseDate: Date?
    // Additive and optional so CloudKit accepts it; nil means use `releaseDate`.
    var sortDate: Date?
    var runtime: Int?
    var addedAt: Date = Date()

    var list: MediaList?

    convenience init(movie: Movie) {
        self.init(key: movie.mediaKey)
    }

    init(key: MediaKey) {
        self.tmdbID = key.tmdbID
        self.mediaTypeRaw = key.mediaType.rawValue
        self.title = key.title
        self.posterPath = key.posterPath
        self.releaseDate = key.releaseDate
        self.sortDate = key.sortDate
        self.runtime = key.runtime
    }

    func refreshSnapshot(from key: MediaKey) {
        title = key.title
        posterPath = key.posterPath
        releaseDate = key.releaseDate
        runtime = key.runtime
        if let sortDate = key.sortDate { self.sortDate = sortDate }
    }

    var mediaType: MediaType { MediaType(rawValue: mediaTypeRaw) ?? .movie }

    func posterURL(_ size: PosterSize = .w185) -> URL? {
        TMDBWrapper.imageURL(path: posterPath, size: size.rawValue)
    }

    var movie: Movie {
        var movie = Movie(id: tmdbID, title: title)
        movie.poster = posterPath
        movie.releaseDate = releaseDate
        movie.runtime = runtime
        return movie
    }
}

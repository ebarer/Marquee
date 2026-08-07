//
//  ListEntry.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// A title's membership in one `MediaList` — a display snapshot, no personal facts.
@Model
final class ListEntry {
    var tmdbID: Int = 0
    var mediaTypeRaw: Int = MediaType.movie.rawValue
    var title: String = ""
    var posterPath: String?
    var releaseDate: Date?
    var runtime: Int?
    var addedAt: Date = Date()

    var list: MediaList?

    init(movie: Movie) {
        self.tmdbID = movie.id
        self.title = movie.title
        self.posterPath = movie.poster
        self.releaseDate = movie.releaseDate
        self.runtime = movie.runtime
    }

    var mediaType: MediaType { MediaType(rawValue: mediaTypeRaw) ?? .movie }

    func posterURL(_ size: Movie.PosterSize = .w185) -> URL? {
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

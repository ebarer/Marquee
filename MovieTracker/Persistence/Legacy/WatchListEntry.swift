//
//  WatchListEntry.swift
//  MovieTracker
//
//  LEGACY — kept only so the one-shot launch migration can read pre-restructure
//  data (see the migration in RootView). Superseded by MediaItem + ListEntry.
//  Removed once the migration has been verified on device.
//

import Foundation
import SwiftData

@Model
final class WatchListEntry {
    var uuid: UUID = UUID()
    var movieID: Int = 0
    var title: String = ""
    var posterPath: String?
    var releaseDate: Date?
    var dateAdded: Date = Date()
    var dateWatched: Date?
    var userRating: Double?
    var runtime: Int?

    /// The list this entry belonged to (inverse of `MovieList.entries`).
    var list: MovieList?

    init(movie: Movie) {
        self.uuid = UUID()
        self.movieID = movie.id
        self.title = movie.title
        self.posterPath = movie.poster
        self.releaseDate = movie.releaseDate
        self.dateAdded = Date()
        self.runtime = movie.runtime
    }
}

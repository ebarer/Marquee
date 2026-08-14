//
//  MediaSnapshot.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// A Sendable snapshot of a row, handed from the background build context to the UI.
struct MediaSnapshot: Identifiable, Sendable, Equatable {
    let persistentID: PersistentIdentifier
    let tmdbID: Int
    let mediaType: MediaType
    let title: String
    let posterPath: String?
    let releaseDate: Date?
    let sortDate: Date?
    /// Set for a watched-season row (the show's season number); nil for movies and shows.
    let seasonNumber: Int?
    /// Season progress for a watched-season row: watched vs. total episodes.
    let seasonWatched: Int?
    let seasonTotal: Int?
    /// Air date of the season's first unwatched episode; set only for tracked-season rows.
    let nextEpisodeDate: Date?
    let runtime: Int?
    let dateWatched: Date?
    let userRating: Double?

    var id: PersistentIdentifier { persistentID }
}

// MARK: - TMDB values

/// The value a row navigates to and keys its store writes by. Only what the row and the
/// detail header need is carried; the detail screen refetches the rest.
extension MediaSnapshot {
    var movie: Movie {
        var movie = Movie(id: tmdbID, title: title)
        movie.poster = posterPath
        movie.releaseDate = releaseDate
        movie.runtime = runtime
        return movie
    }

    func show(openingSeason: Int? = nil) -> Show {
        var show = Show(id: tmdbID, name: title)
        show.poster = posterPath
        show.firstAirDate = releaseDate
        show.initialSeason = openingSeason
        return show
    }
}

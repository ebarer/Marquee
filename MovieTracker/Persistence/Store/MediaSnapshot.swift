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
    let seasonNumber: Int?
    let seasonWatched: Int?
    let seasonTotal: Int?
    let nextEpisodeDate: Date?
    let runtime: Int?
    let dateWatched: Date?
    let userRating: Double?

    var id: PersistentIdentifier { persistentID }
}

// MARK: - TMDB values

/// The value a row navigates to and keys its store writes by.
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

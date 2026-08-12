//
//  MediaRef.swift
//  MovieTracker
//

import Foundation

/// A heterogeneous reference to a movie or show, for mixed collections (unified
/// search results, a person's interlaced credits). Reads route through the shared
/// facets below; writes stay type-specific at the call site.
enum MediaRef: Hashable, Identifiable, Sendable {
    case movie(Movie)
    case show(Show)

    var id: String {
        switch self {
        case .movie(let movie): return "movie-\(movie.id)"
        case .show(let show): return "show-\(show.id)"
        }
    }

    var popularity: Double {
        switch self {
        case .movie(let movie): return movie.popularity ?? 0
        case .show(let show): return show.popularity ?? 0
        }
    }

    /// Enduring notability (TMDB vote count), used to tier strong matches above noise.
    var voteCount: Int {
        switch self {
        case .movie(let movie): return movie.voteCount ?? 0
        case .show(let show): return show.voteCount ?? 0
        }
    }

    var isMovie: Bool {
        if case .movie = self { return true }
        return false
    }

    var title: String {
        switch self {
        case .movie(let movie): return movie.title
        case .show(let show): return show.name
        }
    }

    /// Release date (movie) or first air date (show), for date-based grouping/sorting.
    var date: Date? {
        switch self {
        case .movie(let movie): return movie.releaseDate
        case .show(let show): return show.firstAirDate
        }
    }

    var creditRole: String? {
        switch self {
        case .movie(let movie): return movie.creditRole
        case .show(let show): return show.creditRole
        }
    }

    var isExtraneousCredit: Bool {
        switch self {
        case .movie(let movie): return movie.isExtraneousCredit
        case .show(let show): return show.isExtraneousCredit
        }
    }
}

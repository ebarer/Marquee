//
//  MediaRef.swift
//  MovieTracker
//

import Foundation

/// A movie-or-show reference for mixed collections; writes stay type-specific at the call site.
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

    var date: Date? {
        switch self {
        case .movie(let movie): return movie.releaseDate
        case .show(let show): return show.firstAirDate
        }
    }

    var creditRoleSummary: String? {
        switch self {
        case .movie(let movie): return movie.creditRoleSummary
        case .show(let show): return show.creditRoleSummary
        }
    }

    var creditKind: CreditKind {
        switch self {
        case .movie(let movie): return movie.creditKind ?? .crew
        case .show(let show): return show.creditKind ?? .crew
        }
    }

    // Falls back to the single kind for credits decoded before the set existed.
    var creditKinds: Set<CreditKind> {
        switch self {
        case .movie(let movie): return movie.creditKinds ?? [creditKind]
        case .show(let show): return show.creditKinds ?? [creditKind]
        }
    }

    var isExtraneousCredit: Bool {
        switch self {
        case .movie(let movie): return movie.isExtraneousCredit
        case .show(let show): return show.isExtraneousCredit
        }
    }
}

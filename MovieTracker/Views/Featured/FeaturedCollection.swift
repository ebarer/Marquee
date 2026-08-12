//
//  FeaturedCollection.swift
//  MovieTracker
//

import Foundation

enum FeaturedCollection: Int, CaseIterable, Identifiable {
    case popular
    case nowPlaying
    case comingSoon
    case showsPopular
    case showsOnTheAir

    var id: Int { rawValue }

    /// Whether this shelf lists TV shows rather than movies.
    var isShow: Bool {
        switch self {
        case .showsPopular, .showsOnTheAir: return true
        default: return false
        }
    }

    var title: String {
        switch self {
        case .popular: return "Popular"
        case .nowPlaying: return "Now Playing"
        case .comingSoon: return "Coming Soon"
        case .showsPopular: return "Popular Shows"
        case .showsOnTheAir: return "On The Air"
        }
    }

    var symbol: String {
        switch self {
        case .popular: return "star.fill"
        case .nowPlaying: return "popcorn.fill"
        case .comingSoon: return "calendar"
        case .showsPopular: return "tv.fill"
        case .showsOnTheAir: return "antenna.radiowaves.left.and.right"
        }
    }
}

// MARK: - Fetching

extension FeaturedCollection {
    func movies(page: Int) async throws -> PagedResult<Movie> {
        switch self {
        case .nowPlaying: return try await TMDBWrapper.moviesNowPlaying(page: page)
        case .comingSoon: return try await TMDBWrapper.moviesComingSoon(page: page)
        default: return try await TMDBWrapper.moviesPopular(page: page)
        }
    }

    func shows(page: Int) async throws -> PagedResult<Show> {
        switch self {
        case .showsOnTheAir: return try await TMDBWrapper.showsOnTheAir(page: page)
        default: return try await TMDBWrapper.showsPopular(page: page)
        }
    }
}

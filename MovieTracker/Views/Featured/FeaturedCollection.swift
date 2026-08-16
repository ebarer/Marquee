//
//  FeaturedCollection.swift
//  MovieTracker
//

import SwiftUI

// Ordered as the sidebar and the title menu show them: current first, popular last in each group.
enum FeaturedCollection: Int, CaseIterable, Identifiable {
    case nowPlaying
    case comingSoon
    case popularMovies
    case showsOnTheAir
    case popularShows

    static var movieCases: [FeaturedCollection] { allCases.filter { !$0.isShow } }
    static var showCases: [FeaturedCollection] { allCases.filter(\.isShow) }

    var id: Int { rawValue }

    /// Whether this shelf lists TV shows rather than movies.
    var isShow: Bool {
        switch self {
        case .popularShows, .showsOnTheAir: return true
        default: return false
        }
    }

    var title: String {
        switch self {
        case .nowPlaying: return "Now Playing"
        case .comingSoon: return "Coming Soon"
        case .popularMovies: return "Popular Movies"
        case .showsOnTheAir: return "On Air"
        case .popularShows: return "Popular Shows"
        }
    }

    var symbol: String {
        switch self {
        case .popularMovies: return "custom.film.badge.sparkles"
        case .nowPlaying: return "popcorn.fill"
        case .comingSoon: return "calendar"
        case .popularShows: return "custom.tv.badge.sparkles"
        case .showsOnTheAir: return "antenna.radiowaves.left.and.right"
        }
    }

    /// A name SF Symbols doesn't know is an asset-catalog symbol, which `Image(systemName:)`
    /// (and so `Label(_:systemImage:)`) can't resolve.
    var icon: Image {
        UIImage(systemName: symbol) == nil ? Image(symbol) : Image(systemName: symbol)
    }

    var label: Label<Text, Image> {
        Label { Text(title) } icon: { icon }
    }
}

// MARK: - Fetching

extension FeaturedCollection {
    func movies(page: Int) async throws -> PagedResult<Movie> {
        switch self {
        case .nowPlaying: return try await TMDBWrapper.moviesNowPlaying(page: page)
        case .comingSoon: return try await TMDBWrapper.moviesComingSoon(page: page)
        case .popularMovies: return try await TMDBWrapper.moviesPopular(page: page)
        default: return PagedResult<Movie>.empty
        }
    }

    func shows(page: Int) async throws -> PagedResult<Show> {
        switch self {
        case .showsOnTheAir: return try await TMDBWrapper.showsOnTheAir(page: page)
        case .popularShows: return try await TMDBWrapper.showsPopular(page: page)
        default: return PagedResult<Show>.empty
        }
    }
}

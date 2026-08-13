//
//  SearchProvider.swift
//  MovieTracker
//
//  The network surface a SearchPolicy and its tools draw on. Abstracting TMDB
//  behind this protocol lets policies/tools run against canned data in tests.
//

import Foundation

protocol SearchProvider: Sendable {
    func movies(matching query: String) async -> [Movie]
    func shows(matching query: String) async -> [Show]
    func people(matching query: String) async -> [Person]
    func collection(id: Int) async -> [Movie]
    /// Light detail (base fields + credits) for a movie: one call yields both the
    /// collection (franchise expansion) and the cast (People strip).
    func movieDetail(id: Int) async -> Movie?
    func show(id: Int) async -> Show?
}

/// Live implementation backed by TMDBWrapper. Each call degrades to empty/nil on
/// failure so one endpoint's error never discards another's results.
struct TMDBSearchProvider: SearchProvider {
    func movies(matching query: String) async -> [Movie] {
        (try? await TMDBWrapper.searchForMovies(query: query).items) ?? []
    }

    func shows(matching query: String) async -> [Show] {
        (try? await TMDBWrapper.searchForShows(query: query).items) ?? []
    }

    func people(matching query: String) async -> [Person] {
        (try? await TMDBWrapper.searchForPeople(query: query).items) ?? []
    }

    func collection(id: Int) async -> [Movie] {
        (try? await TMDBWrapper.getCollection(id: id)) ?? []
    }

    func movieDetail(id: Int) async -> Movie? {
        try? await TMDBWrapper.movieSearchDetail(id: id)
    }

    func show(id: Int) async -> Show? {
        try? await TMDBWrapper.getShow(id: id)
    }
}

//
//  SearchProvider.swift
//  MovieTracker
//
//  The network surface a `SearchPolicy` draws on, so policies can run against canned data in tests.
//

import Foundation

protocol SearchProvider: Sendable {
    func movies(matching query: String) async -> [Movie]
    func shows(matching query: String) async -> [Show]
    func people(matching query: String) async -> [Person]
    func collection(id: Int) async -> [Movie]
    func movieDetail(id: Int) async -> Movie?
    func show(id: Int) async -> Show?
    func popularityBenchmark() async -> Double?
}

extension SearchProvider {
    func popularityBenchmark() async -> Double? { nil }
}

/// Live implementation backed by `TMDBWrapper`; each call degrades to empty on failure.
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

    func popularityBenchmark() async -> Double? {
        await PopularityBenchmark.shared.current()
    }
}

/// The median of TMDB's popular list, so the benchmark survives a rescaling of `popularity`.
private actor PopularityBenchmark {
    static let shared = PopularityBenchmark()

    private var value: Double?
    private var fetchedAt: Date?
    private let lifetime: TimeInterval = 6 * 60 * 60

    func current() async -> Double? {
        if let fetchedAt, Date.now.timeIntervalSince(fetchedAt) < lifetime { return value }
        guard let popular = try? await TMDBWrapper.moviesPopular(page: 1).items else { return value }

        let ranked = popular.compactMap(\.popularity).sorted()
        guard !ranked.isEmpty else { return value }
        value = ranked[ranked.count / 2]
        fetchedAt = .now
        return value
    }
}

//
//  FeaturedModel.swift
//  MovieTracker
//

import SwiftUI

@MainActor
@Observable
final class FeaturedModel {
    private(set) var movies: [Movie] = []
    private(set) var shows: [Show] = []
    private(set) var isLoading = false

    private var collection: FeaturedCollection = .popular
    private var lastPageFetched = 0
    private var totalPages = 1

    /// Idempotent for the showing collection so a re-fired `.task` doesn't wipe and
    /// reload (which would reset scroll position); a different collection still reloads.
    func load(_ collection: FeaturedCollection) async {
        let alreadyLoaded = collection.isShow ? !shows.isEmpty : !movies.isEmpty
        guard collection != self.collection || !alreadyLoaded else { return }
        self.collection = collection
        movies = []
        shows = []
        lastPageFetched = 0
        totalPages = 1
        await loadNextPage()
    }

    func loadMoreIfNeeded(currentItem movie: Movie) async {
        guard let index = movies.firstIndex(of: movie) else { return }
        if index >= movies.count - 8 { await loadNextPage() }
    }

    func loadMoreIfNeeded(currentShow show: Show) async {
        guard let index = shows.firstIndex(of: show) else { return }
        if index >= shows.count - 8 { await loadNextPage() }
    }

    private func loadNextPage() async {
        guard !isLoading, lastPageFetched < totalPages else { return }
        isLoading = true
        defer { isLoading = false }

        let page = lastPageFetched + 1
        do {
            if collection.isShow {
                let result = try await fetchShows(page: page)
                lastPageFetched = page
                totalPages = result.totalPages
                let existingIDs = Set(shows.map(\.id))
                shows.append(contentsOf: result.items.filter { !existingIDs.contains($0.id) })
            } else {
                let result = try await fetchMovies(page: page)
                lastPageFetched = page
                totalPages = result.totalPages
                let existingIDs = Set(movies.map(\.id))
                movies.append(contentsOf: result.items.filter { !existingIDs.contains($0.id) })
            }
        } catch {
            print("Featured load error: \(error)")
        }
    }

    private func fetchMovies(page: Int) async throws -> PagedResult<Movie> {
        switch collection {
        case .nowPlaying: return try await TMDBWrapper.moviesNowPlaying(page: page)
        case .comingSoon: return try await TMDBWrapper.moviesComingSoon(page: page)
        default: return try await TMDBWrapper.moviesPopular(page: page)
        }
    }

    private func fetchShows(page: Int) async throws -> PagedResult<Show> {
        switch collection {
        case .showsOnTheAir: return try await TMDBWrapper.showsOnTheAir(page: page)
        default: return try await TMDBWrapper.showsPopular(page: page)
        }
    }
}

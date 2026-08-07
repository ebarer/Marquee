//
//  FeaturedModel.swift
//  MovieTracker
//
//  Loads and paginates the Featured movie collections (Now Playing / Coming Soon).
//

import SwiftUI

@MainActor
@Observable
final class FeaturedModel {
    private(set) var movies: [Movie] = []
    private(set) var isLoading = false

    private var collection: FeaturedCollection = .popular
    private var lastPageFetched = 0
    private var totalPages = 1

    /// Loads `collection`, unless it's already the one showing. Idempotent so a
    /// re-fired `.task` — e.g. the grid reappearing after a push → pop — doesn't
    /// wipe and reload the movies, which would reset the grid's scroll position.
    /// Switching to a different collection still resets and reloads.
    func load(_ collection: FeaturedCollection) async {
        guard collection != self.collection || movies.isEmpty else { return }
        self.collection = collection
        movies = []
        lastPageFetched = 0
        totalPages = 1
        await loadNextPage()
    }

    /// Triggers pagination as the user approaches the end of the grid.
    func loadMoreIfNeeded(currentItem movie: Movie) async {
        guard let index = movies.firstIndex(of: movie) else { return }
        if index >= movies.count - 8 {
            await loadNextPage()
        }
    }

    private func loadNextPage() async {
        guard !isLoading, lastPageFetched < totalPages else { return }
        isLoading = true
        defer { isLoading = false }

        let page = lastPageFetched + 1
        do {
            let result: PagedResult<Movie>
            switch collection {
            case .popular: result = try await TMDBWrapper.moviesPopular(page: page)
            case .nowPlaying: result = try await TMDBWrapper.moviesNowPlaying(page: page)
            case .comingSoon: result = try await TMDBWrapper.moviesComingSoon(page: page)
            }

            lastPageFetched = page
            totalPages = result.totalPages

            let existingIDs = Set(movies.map(\.id))
            movies.append(contentsOf: result.items.filter { !existingIDs.contains($0.id) })
        } catch {
            print("Featured load error: \(error)")
        }
    }
}

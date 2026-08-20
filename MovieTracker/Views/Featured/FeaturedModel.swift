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
    // Trails `load`'s argument until the first page lands, which lets the grid cross-dissolve instead of blanking.
    private(set) var loadedCollection: FeaturedCollection = .nowPlaying

    private var collection: FeaturedCollection = .nowPlaying
    private var lastPageFetched = 0
    private var totalPages = 1

    // Idempotent for the showing collection: a re-fired `.task` would otherwise wipe and reload, resetting scroll.
    func load(_ collection: FeaturedCollection) async {
        let alreadyLoaded = collection.isShow ? !shows.isEmpty : !movies.isEmpty
        guard collection != self.collection || !alreadyLoaded else { return }
        self.collection = collection
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
        // The previous collection stays on screen until this page lands, then the whole grid is replaced
        // in one update. Clearing first would blank it for the length of the fetch.
        let replaces = page == 1
        do {
            if collection.isShow {
                let result = try await collection.shows(page: page)
                lastPageFetched = page
                totalPages = result.totalPages
                if replaces {
                    replace(movies: [], shows: result.items)
                } else {
                    let existingIDs = Set(shows.map(\.id))
                    shows.append(contentsOf: result.items.filter { !existingIDs.contains($0.id) })
                }
            } else {
                let result = try await collection.movies(page: page)
                lastPageFetched = page
                totalPages = result.totalPages
                if replaces {
                    replace(movies: result.items, shows: [])
                } else {
                    let existingIDs = Set(movies.map(\.id))
                    movies.append(contentsOf: result.items.filter { !existingIDs.contains($0.id) })
                }
            }
        } catch {
            // Leaving the old items up would contradict the title, so the grid empties.
            if replaces { replace(movies: [], shows: []) }
            print("Featured load error: \(error)")
        }
    }

    private func replace(movies: [Movie], shows: [Show]) {
        self.movies = movies
        self.shows = shows
        loadedCollection = collection
    }
}

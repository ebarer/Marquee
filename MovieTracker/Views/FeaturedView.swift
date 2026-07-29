//
//  FeaturedView.swift
//  MovieTracker
//
//  Featured movies grid. A toolbar button toggles between the
//  Now Playing and Coming Soon collections. Replaces FeaturedViewController.
//

import SwiftUI

enum FeaturedCollection: Int, CaseIterable, Identifiable {
    case nowPlaying
    case comingSoon

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: return "Now Playing"
        case .comingSoon: return "Coming Soon"
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: return "popcorn.fill"
        case .comingSoon: return "calendar"
        }
    }

    var toggled: FeaturedCollection {
        self == .nowPlaying ? .comingSoon : .nowPlaying
    }
}

@MainActor
@Observable
final class FeaturedModel {
    private(set) var movies: [Movie] = []
    private(set) var isLoading = false

    private var collection: FeaturedCollection = .nowPlaying
    private var lastPageFetched = 0
    private var totalPages = 1

    /// Loads the first page for the initial collection (no-op if already loaded).
    func start(_ collection: FeaturedCollection) async {
        guard movies.isEmpty else { return }
        self.collection = collection
        await loadNextPage()
    }

    /// Resets and reloads when the user switches collections.
    func change(to collection: FeaturedCollection) async {
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

struct FeaturedView: View {
    @State private var model = FeaturedModel()
    @State private var collection: FeaturedCollection = .nowPlaying

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(model.movies, id: \.id) { movie in
                    NavigationLink(value: movie) {
                        MoviePosterCard(movie: movie)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            movie.tracked = true
                        } label: {
                            Label("Want to Watch", systemImage: "bookmark")
                        }
                        Button {
                            movie.watched = true
                        } label: {
                            Label("Watched", systemImage: "checkmark.circle")
                        }
                    }
                    .task {
                        await model.loadMoreIfNeeded(currentItem: movie)
                    }
                }
            }
            .padding(10)
        }
        .background(Color.appBackground)
        .navigationTitle(collection.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    collection = collection.toggled
                } label: {
                    Label("Show \(collection.toggled.title)", systemImage: collection.toggled.symbol)
                }
            }
        }
        .overlay {
            if model.isLoading && model.movies.isEmpty {
                ProgressView()
            }
        }
        .onChange(of: collection) { _, newValue in
            Task { await model.change(to: newValue) }
        }
        .task {
            await model.start(collection)
        }
    }
}

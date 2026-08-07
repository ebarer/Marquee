//
//  MovieDetailView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The movie detail screen composed over an async-loaded movie.
struct MovieDetailView: View {
    private let movieID: Int
    private let movieTitle: String

    init(movie: Movie) {
        self.movieID = movie.id
        self.movieTitle = movie.title
    }

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @State private var model = MovieDetailModel()
    @State private var showNavTitle = false
    @State private var isSeen = false

    var body: some View {
        Group {
            if let movie = model.movie {
                detailContent(movie: movie)
            } else {
                loadingView
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .tint(model.tint)
        .navigationTitle(model.movie?.title ?? movieTitle)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(showNavTitle ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(model.movie?.title ?? movieTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .opacity(showNavTitle ? 1 : 0)
            }
        }
        .task {
            isSeen = store?.isWatched(Movie(id: movieID, title: movieTitle)) ?? false
            await model.load(id: movieID)
            if let movie = model.movie {
                store?.recordView(movie)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(movieTitle)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detailContent(movie: Movie) -> some View {
        GeometryReader { container in
            // This reader sits below the nav bar, so its global top edge is the bar's
            // bottom edge (safeAreaInsets.top reads 0 here). The ScrollView ignores the
            // top safe area so the backdrop draws under the bar.
            let navBarBottom = container.frame(in: .global).minY
            let fullHeight = container.size.height + navBarBottom
            let imageHeight = fullHeight * 0.45
            let headerHeight = fullHeight * 0.54
            let width = container.size.width

            ScrollView {
                VStack(spacing: 0) {
                    MovieDetailHeader(movie: movie, tint: model.tint, lists: lists,
                                      imageHeight: imageHeight, headerHeight: headerHeight,
                                      width: width, navBarBottom: navBarBottom,
                                      showNavTitle: $showNavTitle, isSeen: $isSeen)
                    MovieMetadataStrip(movie: movie, tint: model.tint, isWatched: isSeen)
                        .padding(.vertical, 8)
                    MovieOverviewSection(overview: movie.overview ?? "No movie description available.")
                    WhereToWatchSection(availabilityByRegion: movie.watchByRegion,
                                        releaseDate: movie.releaseDate, tint: model.tint)
                    RelatedMoviesSection(collection: model.collection,
                                         recommendations: model.recommendations,
                                         lists: lists, tint: model.tint)
                    MovieCastSection(cast: movie.team, tint: model.tint)
                }
                .padding(.bottom, 24)
            }
            .coordinateSpace(name: "scroll")
            .scrollEdgeEffectHidden(!showNavTitle, for: .top)
            .ignoresSafeArea(edges: .top)
        }
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(movie: .preview)
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

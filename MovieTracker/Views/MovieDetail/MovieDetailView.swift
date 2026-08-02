//
//  MovieDetailView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The movie detail screen: a parallax backdrop header, metadata strip, expandable
/// overview, related movies, and cast, composed over an async-loaded movie.
struct MovieDetailView: View {
    private let movieID: Int
    private let movieTitle: String

    init(movie: Movie) {
        self.movieID = movie.id
        self.movieTitle = movie.title
    }

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @State private var model = MovieDetailModel()
    @State private var showNavTitle = false
    /// Whether the movie is Watched; owned here so the action bar and the metadata
    /// strip's rating cell stay in sync.
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
            isSeen = MediaItem.find(tmdbID: movieID, in: context)?.isWatched ?? false
            await model.load(id: movieID)
            if let movie = model.movie {
                MediaItem.recordView(movie, in: context)
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
                    MovieDetailHeader(movie: movie, tint: model.tint, lists: lists, context: context,
                                      imageHeight: imageHeight, headerHeight: headerHeight,
                                      width: width, navBarBottom: navBarBottom,
                                      showNavTitle: $showNavTitle, isSeen: $isSeen)
                    MovieMetadataStrip(movie: movie, context: context,
                                       tint: model.tint, isWatched: isSeen)
                        .padding(.vertical, 8)
                    MovieOverviewSection(overview: movie.overview ?? "No movie description available.")
                    RelatedMoviesSection(collection: model.collection,
                                         recommendations: model.recommendations,
                                         lists: lists, context: context, tint: model.tint)
                    MovieCastSection(cast: movie.team)
                }
                .padding(.bottom, 24)
            }
            .coordinateSpace(name: "scroll")
            // Hide the top scroll-edge blur until the title appears, so the bar reads
            // as transparent over the backdrop on first presentation.
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
    .preferredColorScheme(.dark)
}

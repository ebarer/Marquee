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
    @State private var headerPinned = false
    @State private var isSeen = false
    /// Top over-scroll (rubber-band) distance, from the scroll geometry — drives the
    /// backdrop's elastic stretch. `frame(in:)` doesn't report top bounce reliably.
    @State private var overscroll: CGFloat = 0

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
        // The pinned header carries the title, so the nav bar stays chromeless and the
        // backdrop reads through it.
        .navigationTitle(model.movie?.title ?? movieTitle)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("") // Visually overrides the center title space
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
            let headerRest = fullHeight * 0.54

            ScrollView {
                // The header is the first child (in-flow, so its rest layout and pull-down
                // stretch match the original exactly) with a high zIndex so it draws over
                // the sections and the page scrolls underneath it once pinned.
                VStack(spacing: 0) {
                    MovieDetailHeader(movie: movie, tint: model.tint, lists: lists,
                                      navBarBottom: navBarBottom, imageHeight: imageHeight,
                                      headerRest: headerRest, overscroll: overscroll,
                                      headerPinned: $headerPinned, isSeen: $isSeen)
                        .zIndex(1)
                    MovieMetadataStrip(movie: movie, tint: model.tint, isWatched: isSeen)
                        .padding(.bottom, 8)
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
            .scrollEdgeEffectHidden(!headerPinned, for: .top)
            // Also ignore horizontal safe area — otherwise the content sits in a slightly
            // inset region (leading-aligned) and the background shows as a trailing gutter.
            .ignoresSafeArea(edges: [.top, .horizontal])
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                max(0, -(geo.contentOffset.y + geo.contentInsets.top))
            } action: { _, newValue in
                overscroll = newValue
            }
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

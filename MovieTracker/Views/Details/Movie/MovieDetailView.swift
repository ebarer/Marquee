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

    /// Previews only: inject a pre-seeded model so the screen renders populated state offline.
    init(preview movie: Movie, model: MovieDetailModel) {
        self.movieID = movie.id
        self.movieTitle = movie.title
        _model = State(initialValue: model)
    }

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @State private var model = MovieDetailModel()
    @State private var headerPinned = false
    @State private var isSeen = false
    // Top over-scroll (rubber-band) distance, from the scroll geometry — drives the
    // backdrop's elastic stretch. frame(in:) doesn't report top bounce reliably.
    @State private var overscroll: CGFloat = 0

    var body: some View {
        Group {
            if let movie = model.movie {
                detailContent(movie: movie)
            } else {
                DetailLoadingView(title: movieTitle)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .tint(model.tint)
        .pageTint(model.tint)
        // The pinned header carries the title, so the nav bar stays chromeless.
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

    private func detailContent(movie: Movie) -> some View {
        GeometryReader { container in
            // This reader sits below the nav bar, so its global top edge is the bar's bottom
            // edge. The ScrollView ignores the top safe area so the backdrop draws under it.
            let navBarBottom = container.frame(in: .global).minY
            let fullHeight = container.size.height + navBarBottom
            let imageHeight = fullHeight * 0.45
            let headerRest = fullHeight * 0.54

            ScrollView {
                // The header is the first child (high zIndex) so it draws over the sections
                // and the page scrolls underneath it once pinned.
                VStack(spacing: 0) {
                    MovieDetailHeader(movie: movie, tint: model.tint, lists: lists,
                                      navBarBottom: navBarBottom, imageHeight: imageHeight,
                                      headerRest: headerRest, overscroll: overscroll,
                                      headerPinned: $headerPinned, isSeen: $isSeen)
                        .zIndex(1)

                    MovieMetadataStrip(movie: movie, tint: model.tint, isWatched: isSeen)
                        .padding(.bottom, 8)

                    ExpandableText(text: movie.overview ?? "No movie description available.")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    if let releaseDate = movie.releaseDate, !releaseDate.inTheFuture {
                        WhereToWatchSection(availabilityByRegion: movie.watchByRegion,
                                            releaseDate: releaseDate, tint: model.tint)
                    }

                    RelatedMoviesSection(collection: model.collection,
                                         recommendations: model.recommendations,
                                         lists: lists, tint: model.tint)

                    CastSection(cast: movie.team, tint: model.tint)
                }
                .padding(.bottom, 24)
            }
            .coordinateSpace(name: "scroll")
            .scrollEdgeEffectHidden(!headerPinned, for: .top)
            // Also ignore horizontal safe area — otherwise the content sits inset and the
            // background shows as a trailing gutter.
            .ignoresSafeArea(edges: [.top, .horizontal])
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                max(0, -(geo.contentOffset.y + geo.contentInsets.top))
            } action: { _, newValue in
                overscroll = newValue
            }
        }
    }
}

#Preview("Standard") {
    NavigationStack {
        MovieDetailView(preview: .preview,
                        model: .preview(.preview, recommendations: Movie.previewList))
    }
    .modelContainer(detailPreviewContainer)
    .environment(PersistenceCoordinator(detailPreviewContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Series") {
    NavigationStack {
        MovieDetailView(preview: .previewSeries,
                        model: .preview(.previewSeries, collection: Movie.previewSeriesCollection,
                                        recommendations: Movie.previewList))
    }
    .modelContainer(detailPreviewContainer)
    .environment(PersistenceCoordinator(detailPreviewContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Watched") {
    NavigationStack {
        MovieDetailView(preview: .previewWatched, model: .preview(.previewWatched))
    }
    .modelContainer(detailPreviewContainer)
    .environment(PersistenceCoordinator(detailPreviewContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Loading") {
    NavigationStack {
        MovieDetailView(preview: .preview, model: .previewLoading)
    }
    .modelContainer(detailPreviewContainer)
    .environment(PersistenceCoordinator(detailPreviewContainer.mainContext))
    .preferredColorScheme(.dark)
}

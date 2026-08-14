//
//  MovieDetailView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The movie detail screen. It opens on whatever the caller already had — title, poster,
/// date — and the rest of the payload faults in around it.
struct MovieDetailView: View {
    private let seed: Movie

    init(movie: Movie) {
        seed = movie
        _model = State(initialValue: MovieDetailModel(seed: movie))
    }

    /// Previews only: inject a pre-seeded model so the screen renders populated state offline.
    init(preview movie: Movie, model: MovieDetailModel) {
        seed = movie
        _model = State(initialValue: model)
    }

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @State private var model = MovieDetailModel()
    @State private var headerPinned = false
    /// Nil until asked for, then whatever the user last set. Resolving this in `.task` instead
    /// let the strip's watched cells animate themselves in mid-push.
    @State private var isSeen: Bool?
    // Top over-scroll (rubber-band) distance, from the scroll geometry — drives the
    // backdrop's elastic stretch. frame(in:) doesn't report top bounce reliably.
    @State private var overscroll: CGFloat = 0

    /// The payload once it lands, else the caller's stub.
    private var movie: Movie { model.movie ?? seed }

    /// Read on the first body pass, so the page's first frame already knows.
    private var seen: Bool { isSeen ?? store?.isWatched(seed) ?? false }

    private var seenBinding: Binding<Bool> {
        Binding { seen } set: { isSeen = $0 }
    }

    var body: some View {
        detailContent(movie: movie)
            .background(Color.appBackground.ignoresSafeArea())
            .tint(model.tint)
            // The pinned header carries the title, so the nav bar stays chromeless.
            .navigationTitle(movie.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("") // Visually overrides the center title space
                }
            }
            .task {
                isSeen = seen   // Pin it, so later body passes stop querying the store.
                await model.load(id: seed.id)
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
                                      headerPinned: $headerPinned, isSeen: seenBinding)
                        .zIndex(1)

                    // "Is this known yet" is answered by the same `movie` the fields come from: a
                    // separate flag rendered a pass apart from it and disclosed gaps as empty.
                    MovieMetadataStrip(movie: movie, tint: model.tint, isWatched: seen,
                                       isLoading: !movie.isDetailPayload)
                        .padding(.bottom, 8)

                    overview(movie: movie)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    if let releaseDate = movie.releaseDate, !releaseDate.inTheFuture {
                        WhereToWatchSection(availabilityByRegion: movie.watchByRegion,
                                            releaseDate: releaseDate, tint: model.tint,
                                            isLoading: !movie.isDetailPayload)
                    }

                    RelatedMoviesSection(collection: model.collection, lists: lists,
                                         tint: model.tint)

                    CastSection(cast: movie.team, tint: model.tint)

                    // Held back until the payload is in, so recommendations can't land ahead of
                    // the cast that belongs above them.
                    if movie.isDetailPayload {
                        RecommendationsSection(movies: model.recommendations, lists: lists,
                                               tint: model.tint)
                    }
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

    @ViewBuilder
    private func overview(movie: Movie) -> some View {
        if let overview = movie.overview, !overview.isEmpty {
            ExpandableText(text: overview)
        } else if movie.isDetailPayload {
            ExpandableText(text: "No movie description available.")
        } else {
            // Bars until the payload answers. Only it can say a movie has no description.
            LoadingParagraph()
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

// How the page looks on push from a list row: title, poster, date and runtime are all it has,
// with the rest of the payload still in flight.
#Preview("Faulting in") {
    var stub = Movie(id: Movie.preview.id, title: Movie.preview.title)
    stub.poster = Movie.preview.poster
    stub.releaseDate = Movie.preview.releaseDate
    stub.runtime = Movie.preview.runtime

    return NavigationStack {
        MovieDetailView(preview: stub, model: .previewPending(stub))
    }
    .modelContainer(detailPreviewContainer)
    .environment(PersistenceCoordinator(detailPreviewContainer.mainContext))
    .preferredColorScheme(.dark)
}

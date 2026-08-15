//
//  ShowDetailView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The show detail screen over an async-loaded show. Show-level tracking persists via
/// `PersistenceCoordinator`; per-episode watched state lives in `WatchedEpisode`.
struct ShowDetailView: View {
    private let showID: Int
    private let showTitle: String
    private let initialSeason: Int?

    init(show: Show) {
        self.showID = show.id
        self.showTitle = show.name
        self.initialSeason = show.initialSeason
    }

    /// Previews only: inject a pre-seeded model so the screen renders populated state offline.
    init(preview show: Show, model: ShowDetailModel) {
        self.showID = show.id
        self.showTitle = show.name
        self.initialSeason = show.initialSeason
        _model = State(initialValue: model)
    }

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @State private var model = ShowDetailModel()
    @State private var headerPinned = false
    @State private var isSeen = false
    @State private var overscroll: CGFloat = 0
    /// The page's top edge in window coordinates — a sheet sits inset in the window, so a bare
    /// `.global` reading would count that offset as nav-bar height.
    @State private var pageTop: CGFloat = 0
    /// The season chosen in the episodes picker, lifted here so the header poster can
    /// swap to match. Nil until the user picks one (falls back to `openingSeason`/first).
    @State private var selectedSeason: Int?
    /// Where the viewer is up to, resolved once the show loads — a part-watched show opens
    /// on the season they're in rather than season 1. Nil until then, and for a finished show.
    @State private var inProgressSeason: Int?

    var body: some View {
        Group {
            if let show = model.show {
                detailContent(show: show)
            } else {
                DetailLoadingView(title: showTitle)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .tint(model.tint)
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .task {
            // Seed from the persisted flag (showID only) so the checkmark is correct before
            // the payload loads, rather than flipping once it's computed.
            isSeen = store?.isShowWatchedCached(showID: showID) ?? false
            await model.load(id: showID)
            if let show = model.show {
                store?.recordView(show)
                // Correct list placement for a show added from search (premiere-only date)
                // now that the detail supplies its most-recent air date.
                store?.refreshSnapshot(for: show)
                // Recompute season snapshots (episodes may have been toggled from the episode
                // detail) and derive the show-level watched state.
                store?.reconcileSeasons(for: show)
                refreshInProgressSeason()
                await model.reconcileMembership(using: store)
                isSeen = store?.isShowFullyWatched(show) ?? false
            }
        }
        // Resolve the opening season off the CACHED show, before the network payload lands —
        // otherwise the screen sits on season 1 and jumps once loading finishes.
        .onChange(of: model.show?.id) { refreshInProgressSeason() }
        // Keep the checkmark live when episodes are toggled in the episodes section.
        .onChange(of: store?.revision) {
            if let show = model.show { isSeen = store?.isShowFullyWatched(show) ?? false }
        }
    }

    private func detailContent(show: Show) -> some View {
        GeometryReader { container in
            // The reader sits below the nav bar, so its distance from the page's top edge is the
            // bar's bottom edge — `pageTop`, not 0, because a sheet sits inset in the window.
            let navBarBottom = container.frame(in: .global).minY - pageTop
            let fullHeight = container.size.height + navBarBottom
            let imageHeight = fullHeight * 0.45
            let headerRest = fullHeight * 0.54

            ScrollView {
                VStack(spacing: 0) {
                    pageTopProbe

                    ShowDetailHeader(show: show, tint: model.tint, lists: lists,
                                     navBarBottom: navBarBottom, imageHeight: imageHeight,
                                     headerRest: headerRest, overscroll: overscroll,
                                     seasonPosterPath: seasonPosterPath(for: show),
                                     episodesBySeason: model.seasonEpisodes,
                                     headerPinned: $headerPinned, isSeen: $isSeen,
                                     onChange: reconcileMembership)
                        .zIndex(1)
                    ShowMetadataStrip(show: show, tint: model.tint)
                        .padding(.bottom, 8)
                    ExpandableText(text: show.overview ?? "No show description available.")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    WhereToWatchSection(availabilityByRegion: show.watchByRegion,
                                        releaseDate: show.firstAirDate, isShow: true, tint: model.tint)
                    EpisodesBySeasonSection(show: show, model: model, tint: model.tint,
                                            initialSeason: openingSeason,
                                            selectedSeason: $selectedSeason)
                    CastSection(cast: show.creators + seasonCast(for: show), tint: model.tint,
                                leadRole: "Creator",
                                leadTitleSingular: "Creator", leadTitlePlural: "Creators",
                                castTitle: "Cast", castLimit: 5)
                    RecommendationsSection(shows: model.recommendations, lists: lists,
                                           tint: model.tint)
                }
                .padding(.bottom, 24)
            }
            .coordinateSpace(name: "scroll")
            .scrollEdgeEffectHidden(!headerPinned, for: .top)
            .ignoresSafeArea(edges: [.top, .horizontal])
            // The poster sets the tint, and the header's poster follows the selected season.
            .task(id: seasonPosterPath(for: show)) {
                await model.applyTint(forPoster: seasonPosterPath(for: show))
            }
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                max(0, -(geo.contentOffset.y + geo.contentInsets.top))
            } action: { _, newValue in
                overscroll = newValue
            }
        }
    }

    /// Zero-height, at the top of the scroll content: window position minus scroll-space position
    /// is where the page begins. `ignoresSafeArea` widens what the ScrollView draws, not its frame.
    private var pageTopProbe: some View {
        Color.clear
            .frame(height: 0)
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .global).minY - $0.frame(in: .named("scroll")).minY
            } action: { newValue in
                pageTop = newValue
            }
    }

    private func refreshInProgressSeason() {
        guard let show = model.show else { return }
        inProgressSeason = store?.firstIncompleteSeason(show)?.seasonNumber
    }

    /// Refresh list membership after an action-bar mutation (advance the tracked season,
    /// re-derive the show-level watched state for the checkmark).
    private func reconcileMembership() {
        Task {
            await model.reconcileMembership(using: store)
            if let show = model.show { isSeen = store?.isShowFullyWatched(show) ?? false }
        }
    }

    /// The season the screen opens on: the one the caller asked for (a Watched-list row names
    /// its season), else the one the viewer is part-way through.
    private var openingSeason: Int? { initialSeason ?? inProgressSeason }

    // The season the detail is showing (picker selection, else the opened season, else the
    // first) — drives both the header poster and the cast list.
    private func resolvedSeason(for show: Show) -> Int? {
        selectedSeason ?? openingSeason ?? show.regularSeasons.first?.seasonNumber
    }

    private func seasonPosterPath(for show: Show) -> String? {
        show.regularSeasons.first { $0.seasonNumber == resolvedSeason(for: show) }?.poster ?? show.poster
    }

    private func seasonCast(for show: Show) -> [Person] {
        guard let resolved = resolvedSeason(for: show),
              let cast = model.seasonCast[resolved], !cast.isEmpty else {
            return show.recurringCast
        }
        return cast
    }
}

// Season 1 fully watched (3/3). Its episodes are seeded in `detailPreviewContainer`; the
// view's .task reconciles them into the WatchedSeason snapshot.
#Preview("Season watched") {
    NavigationStack {
        ShowDetailView(preview: .previewWatched, model: .preview(.previewWatched))
    }
    .modelContainer(detailPreviewContainer)
    .environment(PersistenceCoordinator(detailPreviewContainer.mainContext))
    .preferredColorScheme(.dark)
}

// Season 1 partially watched (2/3) — mid-progress, so it stays on the Watch List.
#Preview("Season partial") {
    NavigationStack {
        ShowDetailView(preview: .previewPartial, model: .preview(.previewPartial))
    }
    .modelContainer(detailPreviewContainer)
    .environment(PersistenceCoordinator(detailPreviewContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Loading") {
    NavigationStack {
        ShowDetailView(preview: .preview, model: .previewLoading)
    }
    .modelContainer(detailPreviewContainer)
    .environment(PersistenceCoordinator(detailPreviewContainer.mainContext))
    .preferredColorScheme(.dark)
}

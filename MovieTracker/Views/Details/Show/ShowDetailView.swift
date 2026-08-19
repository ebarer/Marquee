//
//  ShowDetailView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The show detail screen. It opens on whatever the caller already had — name, poster, air
/// date — and the rest of the payload faults in around it.
struct ShowDetailView: View {
    private let seed: Show

    init(show: Show) {
        seed = show
        _model = State(initialValue: ShowDetailModel(seed: show))
    }

    /// Previews only: inject a pre-seeded model so the screen renders populated state offline.
    init(preview show: Show, model: ShowDetailModel) {
        seed = show
        _model = State(initialValue: model)
    }

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @State private var model = ShowDetailModel()
    @State private var headerPinned = false
    /// The action bar's tracked/watched/caught-up facts, owned here so they're already right
    /// on the first frame the bar draws.
    @State private var progress = ShowProgress()
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
    /// Set by the cast section once its header scrolls under the pinned one, so its search
    /// button can carry on in the bar.
    @State private var hiddenSearch: DetailSearchRequest?

    /// The payload once it lands, else the caller's stub.
    private var show: Show { model.show ?? seed }

    var body: some View {
        detailContent(show: show)
            .background(Color.appBackground.ignoresSafeArea())
            .tint(model.tint)
            // The pinned header carries the title, so the nav bar stays chromeless.
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .detailChrome(title: show.name, hiddenSearch: hiddenSearch)
            .task {
                // Seed from the persisted facts (the show's id alone) so the controls are correct
                // before the payload loads, rather than flipping once it's computed.
                refreshProgress()
                await model.load(id: seed.id)
                // Only the detail payload carries seasons and air dates, so list placement and
                // the season snapshots wait for it rather than reconciling against the stub.
                guard let show = model.show, show.isDetailPayload else { return }
                store?.recordView(show)
                // Correct list placement for a show added from search (premiere-only date)
                // now that the detail supplies its most-recent air date.
                store?.refreshSnapshot(for: show)
                // Recompute season snapshots (episodes may have been toggled from the episode
                // detail) and derive the show-level watched state.
                store?.reconcileSeasons(for: show)
                refreshInProgressSeason()
                await model.reconcileMembership(using: store)
                refreshProgress()
            }
            // Resolve the opening season as soon as seasons arrive — off the CACHED show, before
            // the network payload lands, or the screen sits on season 1 and jumps once it does.
            .onChange(of: model.show?.seasons.count) { refreshInProgressSeason() }
            // Keep the controls live when episodes are toggled in the episodes section: unwatching
            // one pulls a finished show back onto the Watch List, so the bookmark must follow.
            .onChange(of: store?.revision) { refreshProgress() }
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
                                     headerPinned: $headerPinned, progress: $progress,
                                     onChange: reconcileMembership)
                        .zIndex(1)
                    ShowMetadataStrip(show: show, tint: model.tint,
                                      isLoading: !show.isDetailPayload)
                        .padding(.bottom, 8)
                    overview(show: show)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    WhereToWatchSection(availabilityByRegion: show.watchByRegion,
                                        releaseDate: show.firstAirDate, isShow: true,
                                        tint: model.tint, isLoading: !show.isDetailPayload)
                    EpisodesBySeasonSection(show: show, model: model, tint: model.tint,
                                            initialSeason: openingSeason,
                                            pinLine: navBarBottom + CollapsedHeader.extent,
                                            selectedSeason: $selectedSeason)
                    CastSection(cast: show.creators + seasonCast(for: show), tint: model.tint,
                                leadRole: "Creator",
                                leadTitleSingular: "Creator", leadTitlePlural: "Creators",
                                castTitle: "Top Cast", castLimit: 5,
                                coveredBelow: container.frame(in: .global).minY
                                    + CollapsedHeader.extent,
                                onSearchHiddenChange: { request in
                                    withAnimation(DetailSearch.barHandoff) {
                                        hiddenSearch = request
                                    }
                                })
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

    @ViewBuilder
    private func overview(show: Show) -> some View {
        if let overview = show.overview, !overview.isEmpty {
            ExpandableText(text: overview)
        } else if show.isDetailPayload {
            ExpandableText(text: "No show description available.")
        } else {
            // Bars until the payload answers. Only it can say a show has no description.
            LoadingParagraph()
        }
    }

    private func refreshInProgressSeason() {
        guard let show = model.show else { return }
        inProgressSeason = store?.firstIncompleteSeason(show)?.seasonNumber
    }

    private func refreshProgress() {
        progress = store?.showProgress(showID: seed.id) ?? ShowProgress()
    }

    /// Refresh list membership after an action-bar mutation (advance the tracked season,
    /// re-derive the show-level watched state for the checkmark).
    private func reconcileMembership() {
        Task {
            await model.reconcileMembership(using: store)
            refreshProgress()
        }
    }

    /// The season the screen opens on: the one the caller asked for (a Watched-list row names
    /// its season), else the one the viewer is part-way through.
    private var openingSeason: Int? { seed.initialSeason ?? inProgressSeason }

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
        // The roster is the season's, but the list stands for the show, so the counts are the
        // run's. A season's own credits count that season alone, which understates a regular.
        return cast.map { person in
            guard let total = show.castEpisodeCounts?[person.id] else { return person }
            var person = person
            person.episodeCount = total
            return person
        }
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

// How the page looks on push from a list row: name, poster and first-air date are all it has,
// with the rest of the payload still in flight.
#Preview("Faulting in") {
    let stub = Show.previewStub
    NavigationStack {
        ShowDetailView(preview: stub, model: .previewPending(stub))
    }
    .modelContainer(detailPreviewContainer)
    .environment(PersistenceCoordinator(detailPreviewContainer.mainContext))
    .preferredColorScheme(.dark)
}

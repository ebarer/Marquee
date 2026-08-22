//
//  ShowDetailView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The show detail screen. It opens on what the caller already had, and the payload faults in around it.
struct ShowDetailView: View {
    private let seed: Show

    init(show: Show) {
        seed = show
        _model = State(initialValue: ShowDetailModel(seed: show))
    }

    init(preview show: Show, model: ShowDetailModel) {
        seed = show
        _model = State(initialValue: model)
    }

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @State private var model = ShowDetailModel()
    @State private var headerPinned = false
    @State private var progress = ShowProgress()
    @State private var overscroll: CGFloat = 0
    // A sheet sits inset in the window, so a bare `.global` reading counts that offset as nav-bar height.
    @State private var pageTop: CGFloat = 0
    @State private var selectedSeason: Int?
    // Nil holds the episodes section back rather than let it open on season 1 and flip.
    @State private var inProgressSeason: Int?
    @State private var castSearch: DetailSearchRequest?
    @State private var openLink: ExternalLink?

    private var show: Show { model.show ?? seed }

    var body: some View {
        detailContent(show: show)
            .background(Color.appBackground.ignoresSafeArea())
            .tint(model.tint)
            // The pinned header carries the title, so the nav bar stays chromeless.
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .detailChrome(title: show.name, search: castSearch) {
                ExternalLinksToolbarItem(links: model.extras.links) { openLink = $0 }
            }
            .safariSheet(link: $openLink)
            .task {
                // Seed from the persisted facts (the show's id alone) so the controls are correct
                // before the payload loads, rather than flipping once it's computed.
                refreshProgress()
                await model.load(id: seed.id)
                await model.loadExtras()
                await reconcileAfterPayload()
                await model.loadRecommendations(id: seed.id)
            }
            // Also on the first pass: a re-opened page already holds the cached show's seasons, and waiting for
            // the payload leaves the section on season 1 until it lands.
            .onChange(of: model.show?.seasons.count, initial: true) { refreshInProgressSeason() }
            // Keep the controls live when episodes are toggled in the episodes section: unwatching
            // one pulls a finished show back onto the Watch List, so the bookmark must follow.
            .onChange(of: store?.revision) { refreshProgress() }
    }

    private func detailContent(show: Show) -> some View {
        GeometryReader { container in
            // The reader sits below the nav bar, so its distance from the page's top edge is the bar's bottom
            // edge. `pageTop`, not 0, because a sheet sits inset in the window.
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
                                      isLoading: !show.isDetailPayload,
                                      awards: model.extras.awards,
                                      awardsResolved: model.extras.resolved)
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
                                searchRoster: CastSearchRoster(title: "Guests",
                                                               people: show.guestCast ?? []),
                                creditedShow: show,
                                onSearchRequest: { request in
                                    withAnimation(DetailSearch.barHandoff) {
                                        castSearch = request
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

    // Only the detail payload carries seasons and air dates, so list placement and the season
    // snapshots wait for it rather than reconciling against the stub.
    private func reconcileAfterPayload() async {
        guard let show = model.show, show.isDetailPayload else { return }
        store?.recordView(show)
        // Correct list placement for a show added from search (premiere-only date) now that
        // the detail supplies its most-recent air date.
        store?.refreshSnapshot(for: show)
        // Recompute season snapshots (episodes may have been toggled from the episode detail)
        // and derive the show-level watched state.
        store?.reconcileSeasons(for: show)
        refreshInProgressSeason()
        await model.reconcileMembership(using: store)
        refreshProgress()
    }

    // Window position minus scroll-space position is where the page begins.
    // `ignoresSafeArea` widens what the ScrollView draws, not its frame.
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

    // Resolves to the first season once every season is watched; nil reads as "not resolved yet".
    private func refreshInProgressSeason() {
        guard let show = model.show, let first = show.regularSeasons.first?.seasonNumber else {
            return
        }
        guard store?.firstIncompleteSeason(show) != nil else {
            inProgressSeason = first
            return
        }
        inProgressSeason = store?.nextSeasonToWatch(show)?.seasonNumber ?? first
    }

    private func refreshProgress() {
        progress = store?.showProgress(showID: seed.id) ?? ShowProgress()
    }

    private func reconcileMembership() {
        Task {
            await model.reconcileMembership(using: store)
            refreshProgress()
        }
    }

    private var openingSeason: Int? { seed.initialSeason ?? inProgressSeason }

    // The season the detail is showing: picker selection, else the opened season, else the first.
    // Drives both the header poster and the cast list.
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

#Preview("Season partial") {
    NavigationStack {
        ShowDetailView(preview: .previewPartial, model: .preview(.previewPartial))
    }
    .modelContainer(detailPreviewContainer)
    .environment(PersistenceCoordinator(detailPreviewContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Faulting in") {
    let stub = Show.previewStub
    NavigationStack {
        ShowDetailView(preview: stub, model: .previewPending(stub))
    }
    .modelContainer(detailPreviewContainer)
    .environment(PersistenceCoordinator(detailPreviewContainer.mainContext))
    .preferredColorScheme(.dark)
}

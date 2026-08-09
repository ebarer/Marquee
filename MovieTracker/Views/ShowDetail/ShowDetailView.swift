//
//  ShowDetailView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The show detail screen composed over an async-loaded show. Show-level tracking
/// (watch list / watched / rating / custom lists) persists via `PersistenceCoordinator`;
/// per-episode watched marks remain a local stub until the `WatchedEpisode` model lands.
struct ShowDetailView: View {
    private let showID: Int
    private let showTitle: String
    private let initialSeason: Int?

    init(show: Show) {
        self.showID = show.id
        self.showTitle = show.name
        self.initialSeason = show.initialSeason
    }

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @State private var model = ShowDetailModel()
    @State private var headerPinned = false
    @State private var isSeen = false
    /// Top over-scroll (rubber-band) distance, from the scroll geometry — drives the
    /// backdrop's elastic stretch. `frame(in:)` doesn't report top bounce reliably.
    @State private var overscroll: CGFloat = 0
    /// The season chosen in the episodes picker, lifted here so the header poster can
    /// swap to match. Nil until the user picks one (falls back to `initialSeason`/first).
    @State private var selectedSeason: Int?

    var body: some View {
        Group {
            if let show = model.show {
                detailContent(show: show)
            } else {
                loadingView
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .tint(model.tint)
        // The pinned header carries the title, so the nav bar stays chromeless and the
        // backdrop reads through it.
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .task {
            // Seed from the persisted flag first (showID only) so the checkmark is correct
            // before the payload loads, rather than flipping once it's computed.
            isSeen = store?.isShowWatchedCached(showID: showID) ?? false
            await model.load(id: showID)
            if let show = model.show {
                store?.recordView(show)
                // Correct list placement for a show added from search (premiere-only date)
                // now that the detail supplies its most-recent air date.
                store?.refreshSnapshot(for: show)
                // Recompute season snapshots (episodes may have been toggled from the
                // episode detail) and derive the show-level watched state.
                store?.reconcileSeasons(for: show)
                await model.reconcileMembership(using: store)
                isSeen = store?.isShowFullyWatched(show) ?? false
            }
        }
        // Keep the checkmark live when episodes are toggled in the episodes section.
        .onChange(of: store?.revision) {
            if let show = model.show { isSeen = store?.isShowFullyWatched(show) ?? false }
        }
    }

    /// Refresh list membership after an action-bar mutation (advance the tracked season,
    /// re-derive the show-level watched state for the checkmark).
    private func reconcileMembership() {
        Task {
            await model.reconcileMembership(using: store)
            if let show = model.show { isSeen = store?.isShowFullyWatched(show) ?? false }
        }
    }

    /// The season the detail is currently showing (picker selection, else the opened
    /// season, else the first) — drives both the header poster and the cast list.
    private func resolvedSeason(for show: Show) -> Int? {
        selectedSeason ?? initialSeason ?? show.regularSeasons.first?.seasonNumber
    }

    /// The poster path for the current season (falls back to the show poster), so the
    /// header art matches the season chosen in the episodes picker.
    private func seasonPosterPath(for show: Show) -> String? {
        let resolved = resolvedSeason(for: show)
        return show.regularSeasons.first { $0.seasonNumber == resolved }?.poster ?? show.poster
    }

    /// The current season's cast once loaded; falls back to the show's recurring cast
    /// until the season fetch lands.
    private func seasonCast(for show: Show) -> [Person] {
        guard let resolved = resolvedSeason(for: show),
              let cast = model.seasonCast[resolved], !cast.isEmpty else {
            return show.recurringCast
        }
        return cast
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(showTitle)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detailContent(show: Show) -> some View {
        GeometryReader { container in
            let navBarBottom = container.frame(in: .global).minY
            let fullHeight = container.size.height + navBarBottom
            let imageHeight = fullHeight * 0.45
            let headerRest = fullHeight * 0.54

            ScrollView {
                VStack(spacing: 0) {
                    ShowDetailHeader(show: show, tint: model.tint, lists: lists,
                                     navBarBottom: navBarBottom, imageHeight: imageHeight,
                                     headerRest: headerRest, overscroll: overscroll,
                                     seasonPosterPath: seasonPosterPath(for: show),
                                     headerPinned: $headerPinned, isSeen: $isSeen,
                                     onChange: reconcileMembership)
                        .zIndex(1)
                    ShowMetadataStrip(show: show)
                        .padding(.bottom, 8)
                    MovieOverviewSection(overview: show.overview ?? "No show description available.")
                    WhereToWatchSection(availabilityByRegion: show.watchByRegion,
                                        releaseDate: show.firstAirDate, tint: model.tint)
                    EpisodesBySeasonSection(show: show, model: model, tint: model.tint,
                                            initialSeason: initialSeason,
                                            selectedSeason: $selectedSeason)
                    MovieCastSection(cast: show.creators + seasonCast(for: show), tint: model.tint,
                                     leadRole: "Creator",
                                     leadTitleSingular: "Creator", leadTitlePlural: "Creators",
                                     castTitle: "Cast", castLimit: 5)
                    RelatedShowsSection(shows: model.recommendations, tint: model.tint)
                }
                .padding(.bottom, 24)
            }
            .coordinateSpace(name: "scroll")
            .scrollEdgeEffectHidden(!headerPinned, for: .top)
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
        ShowDetailView(show: .preview)
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

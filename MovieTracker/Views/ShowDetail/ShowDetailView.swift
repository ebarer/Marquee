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
    @State private var showNavTitle = false
    @State private var isSeen = false

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
        .navigationTitle(model.show?.name ?? showTitle)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(showNavTitle ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(model.show?.name ?? showTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .opacity(showNavTitle ? 1 : 0)
            }
        }
        .task {
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
            let headerHeight = fullHeight * 0.54
            let width = container.size.width

            ScrollView {
                VStack(spacing: 0) {
                    ShowDetailHeader(show: show, tint: model.tint, lists: lists,
                                     imageHeight: imageHeight, headerHeight: headerHeight,
                                     width: width, navBarBottom: navBarBottom,
                                     showNavTitle: $showNavTitle, isSeen: $isSeen,
                                     onChange: reconcileMembership)
                    ShowMetadataStrip(show: show, tint: model.tint, isWatched: isSeen)
                        .padding(.vertical, 8)
                    MovieOverviewSection(overview: show.overview ?? "No show description available.")
                    WhereToWatchSection(availabilityByRegion: show.watchByRegion,
                                        releaseDate: show.firstAirDate, tint: model.tint)
                    EpisodesBySeasonSection(show: show, model: model, tint: model.tint,
                                            initialSeason: initialSeason)
                    RelatedShowsSection(shows: model.recommendations, tint: model.tint)
                    MovieCastSection(cast: show.creators + show.recurringCast, tint: model.tint,
                                     leadRole: "Creator",
                                     leadTitleSingular: "Creator", leadTitlePlural: "Creators")
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
        ShowDetailView(show: .preview)
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

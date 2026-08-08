//
//  EpisodeDetailView.swift
//  MovieTracker
//

import SwiftUI

/// Full detail for one episode: a still that extends under the nav bar with the title
/// and air/runtime/score line over a gradient (like the movie/show detail headers),
/// the complete synopsis, and guest cast + crew (reusing `MovieCastSection`).
struct EpisodeDetailView: View {
    let episode: Episode

    @State private var tint: Color = .appAccent
    @State private var showNavTitle = false
    /// The show's series regulars (from the cached show), shown as the "Cast" tab alongside
    /// the episode's Guests and Crew. Empty if the show isn't cached.
    @State private var seriesCast: [Person] = []

    var body: some View {
        GeometryReader { container in
            let navBarBottom = container.frame(in: .global).minY
            let width = container.size.width

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    EpisodeDetailHeader(episode: episode, tint: tint, width: width,
                                        navBarBottom: navBarBottom, showNavTitle: $showNavTitle)

                    MovieOverviewSection(overview: episode.overview ?? "No episode description available.")

                    MovieCastSection(cast: seriesCast + episode.crew, guests: episode.guestCast,
                                     tint: tint)
                }
                .padding(.bottom, 24)
            }
            .coordinateSpace(name: "scroll")
            .scrollEdgeEffectHidden(!showNavTitle, for: .top)
            .ignoresSafeArea(edges: .top)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .tint(tint)
        .navigationTitle(episode.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(showNavTitle ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(episode.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .opacity(showNavTitle ? 1 : 0)
            }
        }
        .task { await loadTint() }
    }

    /// Use the show's poster-derived accent so the episode matches the show detail page,
    /// rather than area-averaging the still (which yields garish tints on photographic
    /// frames). Episodes are reached from the show page, so its cached tint is warm; if the
    /// color wasn't cached, derive it from the cached show poster the same way the show does.
    private func loadTint() async {
        guard let cached = await MediaCacheStore.shared.loadShow(id: episode.showTmdbID) else { return }
        seriesCast = cached.show.recurringCast
        if let color = cached.color {
            withAnimation(.easeInOut) { tint = color }
        } else if let url = cached.show.posterURL(.w342),
                  let data = try? await TMDBWrapper.imageData(from: url) {
            withAnimation(.easeInOut) { tint = Color.averageColor(from: data) }
        }
    }
}

/// The still-backed header: image fills the width and extends up under the nav bar,
/// with a gradient fading to the background and the title + meta line anchored bottom-left.
private struct EpisodeDetailHeader: View {
    let episode: Episode
    let tint: Color
    let width: CGFloat
    let navBarBottom: CGFloat
    @Binding var showNavTitle: Bool

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    var body: some View {
        // The still keeps a 16:9 area below the bar, plus the safe-area strip it draws under.
        let baseHeight = navBarBottom + width * 9.0 / 16.0

        GeometryReader { proxy in
            let minY = proxy.frame(in: .named("scroll")).minY
            let stretch = max(0, minY)                 // grow on pull-down
            let height = baseHeight + stretch

            ZStack(alignment: .bottomLeading) {
                Color.appBackground

                PosterImage(url: episode.stillURL(.w780))
                    .frame(width: width, height: height)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [.clear, .appBackground],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: min(200, height))
                            .allowsHitTesting(false)
                    }

                overlay
                    .padding(16)
            }
            .frame(width: width, height: height)
            .clipped()
            .offset(y: minY > 0 ? -minY : 0)           // pin the top edge under the bar
        }
        .frame(height: baseHeight)
    }

    private var overlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(episode.name)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .onGeometryChange(for: Bool.self) { proxy in
                    // Reveal the nav-bar title once the on-page title scrolls behind the bar.
                    proxy.frame(in: .global).maxY <= navBarBottom
                } action: { crossed in
                    withAnimation(.easeInOut(duration: 0.2)) { showNavTitle = crossed }
                }

            HStack(alignment: .center, spacing: 12) {
                watchedButton
                VStack(alignment: .leading, spacing: 2) {
                    Text(codeAndDate)
                        .foregroundStyle(tint)
                    if episode.duration != nil || (episode.rating ?? 0) > 0 {
                        durationRating
                    }
                }
                .font(.subheadline)
            }
        }
    }

    private var watchedButton: some View {
        Button { toggleWatched() } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isWatched ? .appBackground : tint)
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(isWatched ? .regular.tint(tint).interactive() : .regular.interactive(), in: Circle())
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isWatched)
        .accessibilityLabel(isWatched ? "Mark episode unwatched" : "Mark episode watched")
    }

    private var durationRating: some View {
        HStack(spacing: 5) {
            if let duration = episode.duration {
                Text(duration)
            }
            if let rating = episode.rating, rating > 0 {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                Text(String(format: "%.1f", rating / 2))
            }
        }
        .foregroundStyle(.white.opacity(0.75))
    }

    private var codeAndDate: String {
        var text = "S\(episode.seasonNumber), E\(episode.episodeNumber)"
        if let date = episode.airDate?.toString() { text += "  •  \(date)" }
        return text
    }

    private var isWatched: Bool {
        guard let store else { return false }
        _ = store.revision
        return store.isEpisodeWatched(showID: episode.showTmdbID,
                                      season: episode.seasonNumber, episode: episode.episodeNumber)
    }

    private func toggleWatched() {
        guard let store else { return }
        store.setEpisodeWatched(!isWatched, showID: episode.showTmdbID,
                                season: episode.seasonNumber, episode: episode.episodeNumber)
        // The episode page only knows the show id, so reconcile the season snapshot +
        // list membership (Watch List / tracked season) from the warm show cache. Watching
        // an episode adds the show to the Watch List.
        Task { @MainActor in
            guard let show = await MediaCacheStore.shared.loadShow(id: episode.showTmdbID)?.show else { return }
            store.reconcileSeasons(for: show)
            store.reconcileMembership(show)
        }
    }
}

#Preview {
    NavigationStack {
        EpisodeDetailView(episode: {
            var e = Episode.previewEpisodes[0]
            e.guestCast = Person.previewTeam.filter { $0.type == .Cast }
            e.crew = [Person.preview]
            return e
        }())
        .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

//
//  EpisodeDetailView.swift
//  MovieTracker
//

import SwiftUI

/// Full detail for one episode: still, synopsis, and guest cast plus crew.
struct EpisodeDetailView: View {
    let episode: Episode

    @State private var tint: Color = .appAccent
    @State private var showNavTitle = false
    @State private var seriesCast: [Person] = []

    @Environment(\.detailSearch) private var detailSearch
    private var isSearching: Bool { detailSearch?.isPresented == true }

    init(episode: Episode) {
        self.episode = episode
    }

    init(preview episode: Episode, seriesCast: [Person]) {
        self.episode = episode
        _seriesCast = State(initialValue: seriesCast)
    }

    var body: some View {
        GeometryReader { container in
            let navBarBottom = container.frame(in: .global).minY
            let width = container.size.width

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    EpisodeDetailHeader(episode: episode, tint: tint, width: width,
                                        navBarBottom: navBarBottom, showNavTitle: $showNavTitle)

                    ExpandableText(text: episode.overview ?? "No episode description available.")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    CastSection(cast: seriesCast + episode.crew, guests: episode.guestCast,
                                tint: tint, countsEpisodes: false)
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
        // Both would cover the search field.
        .toolbarBackgroundVisibility(showNavTitle && !isSearching ? .visible : .hidden,
                                    for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(episode.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .opacity(showNavTitle && !isSearching ? 1 : 0)
            }
        }
        .task { await loadShow() }
    }

    // Reachable without passing through the show, so an uncached one is fetched for the cast tab and tint.
    private func loadShow() async {
        if let cached = await MediaCacheStore.shared.loadShow(id: episode.showTmdbID) {
            seriesCast = cached.show.recurringCast
            if let color = cached.color {
                withAnimation(.easeInOut) { tint = color }
            } else {
                await applyPosterTint(from: cached.show)
            }
            return
        }
        guard let show = try? await TMDBWrapper.getShow(id: episode.showTmdbID) else { return }
        seriesCast = show.recurringCast
        let color = await applyPosterTint(from: show)
        await MediaCacheStore.shared.save(show, tint: color)
    }

    // The show's poster accent: area-averaging the still yields garish tints on photographic frames.
    @discardableResult
    private func applyPosterTint(from show: Show) async -> Color? {
        guard let url = show.posterURL(.w342),
              let data = try? await TMDBWrapper.imageData(from: url) else { return nil }
        let color = Color.dominantColor(from: data)
        withAnimation(.easeInOut) { tint = color }
        return color
    }
}

#Preview {
    NavigationStack {
        EpisodeDetailView(episode: {
            var episode = Episode.previewEpisodes[0]
            episode.guestCast = Person.previewTeam.filter { $0.type == .Cast }
            episode.crew = [Person.preview]
            return episode
        }())
        .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

// A host-led show: one regular and a run of guests, so the two share a single list.
#Preview("Guest show") {
    let team = Person.previewTeam.filter { $0.type == .Cast }

    return NavigationStack {
        EpisodeDetailView(preview: {
            var episode = Episode.previewEpisodes[0]
            episode.guestCast = Array(team.dropFirst())
            episode.crew = [Person.preview]
            return episode
        }(), seriesCast: [team[0]])
        .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

// All three tabs: the series regulars the screen fetches, plus the episode's own guests and crew.
#Preview("Series cast") {
    let team = Person.previewTeam.filter { $0.type == .Cast }

    return NavigationStack {
        EpisodeDetailView(preview: {
            var episode = Episode.previewEpisodes[0]
            episode.guestCast = Array(team.suffix(3))
            episode.crew = [Person.preview]
            return episode
        }(), seriesCast: Show.preview.recurringCast)
        .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

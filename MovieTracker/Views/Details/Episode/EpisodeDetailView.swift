//
//  EpisodeDetailView.swift
//  MovieTracker
//

import SwiftUI

/// Full detail for one episode: a still that extends under the nav bar (``EpisodeDetailHeader``),
/// the complete synopsis, and guest cast + crew (reusing ``CastSection``).
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

                    ExpandableText(text: episode.overview ?? "No episode description available.")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    CastSection(cast: seriesCast + episode.crew, guests: episode.guestCast,
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
    /// rather than area-averaging the still (which yields garish tints on photographic frames).
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

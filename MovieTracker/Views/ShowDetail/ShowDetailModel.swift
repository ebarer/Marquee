//
//  ShowDetailModel.swift
//  MovieTracker
//

import SwiftUI

@MainActor
@Observable
final class ShowDetailModel {
    private(set) var show: Show?
    private(set) var tint: Color = .appAccent
    private(set) var recommendations: [Show] = []

    /// Episodes fetched lazily per season number, so long-running shows don't
    /// pull every episode up front.
    private(set) var seasonEpisodes: [Int: [Episode]] = [:]
    private(set) var loadingSeasons: Set<Int> = []

    private var loaded = false

    func load(id: Int) async {
        guard !loaded else { return }
        loaded = true

        if let cached = await MediaCacheStore.shared.loadShow(id: id) {
            show = cached.show
            if let color = cached.color { tint = color }
        }

        do {
            let full = try await TMDBWrapper.getShow(id: id)
            show = full
            var freshTint = tint
            if let url = full.posterURL(.w342),
               let data = try? await TMDBWrapper.imageData(from: url) {
                freshTint = Color.averageColor(from: data)
            }
            withAnimation(.easeInOut) { tint = freshTint }
            await MediaCacheStore.shared.save(full, tint: freshTint)
        } catch {
            print("Show detail load error: \(error)")
        }

        do {
            let page = try await TMDBWrapper.showRecommendations(id: id)
            recommendations = page.items.filter { $0.id != id }
        } catch {
            print("Show recommendations load error: \(error)")
        }
    }

    /// Refresh the show's list membership (Watch List + tracked season) after a mutation.
    /// Loads the first-incomplete season's episodes first so the tracked season can anchor
    /// on the precise next-episode air date.
    func reconcileMembership(using store: PersistenceCoordinator?) async {
        guard let store, let show else { return }
        if let season = store.firstIncompleteSeason(show) {
            await loadSeason(showID: show.id, seasonNumber: season.seasonNumber)
        }
        store.reconcileMembership(show, episodesBySeason: seasonEpisodes)
    }

    func loadSeason(showID: Int, seasonNumber: Int) async {
        guard seasonEpisodes[seasonNumber] == nil,
              !loadingSeasons.contains(seasonNumber) else { return }
        loadingSeasons.insert(seasonNumber)
        defer { loadingSeasons.remove(seasonNumber) }
        do {
            let season = try await TMDBWrapper.getSeason(showID: showID, seasonNumber: seasonNumber)
            seasonEpisodes[seasonNumber] = season.episodes
        } catch {
            print("Season load error: \(error)")
        }
    }
}

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
    /// The billed cast per season (from each season's aggregate credits), so the detail's
    /// cast list follows the selected season — anthologies especially.
    private(set) var seasonCast: [Int: [Person]] = [:]
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
            if !season.cast.isEmpty { seasonCast[seasonNumber] = season.cast }
        } catch {
            print("Season load error: \(error)")
        }
    }
}

// MARK: - Previews

extension ShowDetailModel {
    /// A fully-seeded model whose `load(id:)` no-ops (`loaded == true`); every season's
    /// episodes are pre-filled so the episodes section renders offline without a fetch.
    static func preview(_ show: Show, recommendations: [Show] = [], tint: Color = .appAccent) -> ShowDetailModel {
        let model = ShowDetailModel()
        model.show = show
        model.recommendations = recommendations
        model.tint = tint
        for season in show.seasons {
            model.seasonEpisodes[season.seasonNumber] = season.episodes
        }
        model.loaded = true
        return model
    }

    /// A model stuck in the loading state (no show), for the loading-screen preview.
    static var previewLoading: ShowDetailModel {
        let model = ShowDetailModel()
        model.loaded = true
        return model
    }
}

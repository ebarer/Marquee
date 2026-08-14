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
    /// Tints already derived, keyed by poster path — flipping between seasons is then free.
    private var tintByPoster: [String: Color] = [:]

    func load(id: Int) async {
        guard !loaded else { return }
        loaded = true

        if let cached = await MediaCacheStore.shared.loadShow(id: id) {
            show = cached.show
            if let color = cached.color { tint = color }
            hydrateEpisodes(from: cached.show)
        }

        do {
            let full = try await TMDBWrapper.getShow(id: id)
            show = full
            invalidateGrownSeasons(against: full)
            // Cached for other surfaces only. The visible tint comes from `applyTint`, which
            // follows the poster on screen — assigning it here too would race with that.
            let showTint = await posterTint(path: full.poster) ?? tint
            await MediaCacheStore.shared.save(full, tint: showTint)
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

    /// Re-tint the page for the poster now on screen. Seasons carry their own artwork, so
    /// picking a season re-colours the screen to match the poster the header just swapped in.
    func applyTint(forPoster path: String?) async {
        guard let color = await posterTint(path: path), color != tint else { return }
        withAnimation(.easeInOut) { tint = color }
    }

    /// The average colour of a poster, fetched once per path.
    private func posterTint(path: String?) async -> Color? {
        guard let path else { return nil }
        if let known = tintByPoster[path] { return known }
        guard let url = TMDBWrapper.imageURL(path: path, size: PosterSize.w342.rawValue),
              let data = try? await TMDBWrapper.imageData(from: url) else { return nil }
        let color = Color.dominantColor(from: data)
        tintByPoster[path] = color
        return color
    }

    /// Refresh the show's list membership after a mutation. Loads the first-incomplete
    /// season's episodes first so it can anchor on the precise next-episode air date.
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
            await MediaCacheStore.shared.cacheSeason(showID: showID, season)
        } catch {
            print("Season load error: \(error)")
        }
    }

    /// Seed the per-season episode/cast dictionaries from a cached show whose seasons already
    /// carry episodes, so the episodes section renders instantly (and offline) without a fetch.
    private func hydrateEpisodes(from show: Show) {
        for season in show.seasons where !season.episodes.isEmpty {
            seasonEpisodes[season.seasonNumber] = season.episodes
            if !season.cast.isEmpty { seasonCast[season.seasonNumber] = season.cast }
        }
    }

    /// Drop hydrated episodes for any season that has since grown (a new episode aired), so
    /// `loadSeason` re-fetches it. The fresh show payload carries the up-to-date episode count.
    private func invalidateGrownSeasons(against show: Show) {
        for season in show.seasons {
            if let have = seasonEpisodes[season.seasonNumber], have.count < season.episodeCount {
                seasonEpisodes[season.seasonNumber] = nil
                seasonCast[season.seasonNumber] = nil
            }
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

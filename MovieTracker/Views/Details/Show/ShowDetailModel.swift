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

    private let posterPath: String?
    /// The payload landed; nothing left to fetch.
    private var loaded = false
    /// A fetch is in flight, so a re-entrant `load` doesn't start a second one.
    private var loading = false

    /// `seed` is what the caller already had on screen — name, poster, first-air date. A show
    /// already fetched this session comes back whole from memory instead, so nothing faults in twice.
    init(seed: Show? = nil) {
        posterPath = seed?.poster
        if let cached = MediaMemoryCache.show(id: seed?.id) {
            show = cached.show
            if let color = cached.tint { tint = color }
            hydrateEpisodes(from: cached.show)
        } else {
            show = seed
            if let color = PosterTint.cached(forPath: posterPath) { tint = color }
        }
    }

    func load(id: Int) async {
        guard !loaded, !loading else { return }
        loading = true
        defer { loading = false }

        if let cached = await MediaCacheStore.shared.loadShow(id: id) {
            show = cached.show
            if let color = cached.color { tint = color }
            hydrateEpisodes(from: cached.show)
            MediaMemoryCache.store(cached.show, tint: cached.color)
        }

        // A dropped request must not count as loaded, or the next pass skips the retry and the
        // page sits on the caller's stub for good.
        var interrupted = false

        do {
            let full = try await Self.fetchDetail(id: id)
            show = full
            invalidateGrownSeasons(against: full)
            // Cached for other surfaces only. The visible tint comes from `applyTint`, which
            // follows the poster on screen — assigning it here too would race with that.
            let showTint = await PosterTint.resolve(forPath: full.poster) ?? tint
            MediaMemoryCache.store(full, tint: showTint)
            await MediaCacheStore.shared.save(full, tint: showTint)
        } catch {
            print("Show detail load error: \(error)")
            interrupted = true
        }

        do {
            let page = try await TMDBWrapper.showRecommendations(id: id)
            recommendations = page.items.filter { $0.id != id }
        } catch {
            print("Show recommendations load error: \(error)")
            interrupted = interrupted || error.isCancellation
        }

        loaded = !interrupted
    }

    /// The detail request, held back when a UI test needs the unknown-fields window to be
    /// long enough to observe.
    private static func fetchDetail(id: Int) async throws -> Show {
        if let delay = UITestHooks.detailDelay { try? await Task.sleep(for: delay) }
        return try await TMDBWrapper.getShow(id: id)
    }

    /// Re-tint the page for the poster now on screen. Seasons carry their own artwork, so
    /// picking a season re-colours the screen to match the poster the header just swapped in.
    func applyTint(forPoster path: String?) async {
        guard let color = await PosterTint.resolve(forPath: path), color != tint else { return }
        withAnimation(.easeInOut) { tint = color }
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
        model.show?.isFullDetail = true      // previews stand in for a landed payload
        model.recommendations = recommendations
        model.tint = tint
        for season in show.seasons {
            model.seasonEpisodes[season.seasonNumber] = season.episodes
        }
        model.loaded = true
        return model
    }

    /// A model holding the caller's stub with the payload still pending, for the preview of
    /// the page's faulting-in state.
    static func previewPending(_ seed: Show) -> ShowDetailModel {
        let model = ShowDetailModel(seed: seed)
        model.loaded = true
        return model
    }
}

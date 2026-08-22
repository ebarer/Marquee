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
    private(set) var extras = TitleExtras()

    private(set) var seasonEpisodes: [Int: [Episode]] = [:]
    private(set) var seasonCast: [Int: [Person]] = [:]
    private(set) var loadingSeasons: Set<Int> = []

    private let posterPath: String?
    private var loaded = false
    private var loading = false
    private var interrupted = false

    init(seed: Show? = nil) {
        posterPath = seed?.poster
        let cached = MediaMemoryCache.show(id: seed?.id)
        if let cached {
            show = cached.show
            hydrateEpisodes(from: cached.show)
        } else {
            show = seed
        }
        // Only the seed's poster, which is the one the caller had on screen and the header opens on.
        // A show-level tint would be the wrong season.
        if let color = PosterTint.cached(forPath: posterPath) { tint = color }
    }

    // The page fills top down. This settles the header and the metadata strip's TMDB fields;
    // `loadExtras` then `loadRecommendations` follow, in that order.
    func load(id: Int) async {
        guard !loaded, !loading else { return }
        loading = true
        defer { loading = false }
        interrupted = false

        if let cached = await MediaCacheStore.shared.loadShow(id: id) {
            show = cached.show
            hydrateEpisodes(from: cached.show)
            // The show poster's colour, kept for other surfaces. Taking it here would repaint the page off the
            // wrong artwork, since the header is showing a season's poster.
            MediaMemoryCache.store(cached.show, tint: cached.color)
        }

        do {
            let full = try await Self.fetchDetail(id: id)
            show = full
            invalidateGrownSeasons(against: full)
            // Cached for other surfaces only. The visible tint comes from `applyTint`, which follows the
            // poster on screen, so assigning it here too would race with that.
            let showTint = await PosterTint.resolve(forPath: full.poster) ?? tint
            MediaMemoryCache.store(full, tint: showTint)
            await MediaCacheStore.shared.save(full, tint: showTint)
        } catch {
            // A dropped request must not count as loaded, or the next pass skips the retry and the
            // page sits on the caller's stub for good.
            print("Show detail load error: \(error)")
            interrupted = true
        }
    }

    // Awards and the Rotten Tomatoes link complete the metadata strip.
    func loadExtras() async {
        guard !loaded, !extras.resolved else { return }
        extras = await Self.resolveExtras(for: show)
    }

    // Requested last, so the recommendation row can't land ahead of the rows above it.
    func loadRecommendations(id: Int) async {
        guard !loaded else { return }
        do {
            let page = try await TMDBWrapper.showRecommendations(id: id)
            recommendations = page.items.filter { $0.id != id }
        } catch {
            print("Show recommendations load error: \(error)")
            interrupted = interrupted || error.isCancellation
        }
        loaded = !interrupted
    }

    // `nonisolated` so the SPARQL response decodes off the main actor. A failure here is not load-bearing.
    nonisolated private static func resolveExtras(for show: Show?) async -> TitleExtras {
        guard let show else { return TitleExtras() }
        let imdb = ExternalLink.imdb(id: show.imdbID)

        guard let qid = show.wikidataID else {
            return TitleExtras(links: [
                .rottenTomatoes(slug: nil, title: show.name), imdb,
            ].compactMap { $0 }, resolved: true)
        }

        async let awardsTask = WikidataWrapper.awards(qid: qid)
        async let slugTask = WikidataWrapper.rottenTomatoesID(qid: qid)
        let digest = (try? await awardsTask) ?? AwardsDigest()
        let slug = (try? await slugTask) ?? nil

        return TitleExtras(awards: digest, links: [
            .rottenTomatoes(slug: slug, title: show.name), imdb,
        ].compactMap { $0 }, resolved: true)
    }

    private static func fetchDetail(id: Int) async throws -> Show {
        if let delay = UITestHooks.detailDelay { try? await Task.sleep(for: delay) }
        return try await TMDBWrapper.getShow(id: id)
    }

    func applyTint(forPoster path: String?) async {
        guard let color = await PosterTint.resolve(forPath: path), color != tint else { return }
        withAnimation(.easeInOut) { tint = color }
    }

    func reconcileMembership(using store: PersistenceCoordinator?) async {
        guard let store, let show else { return }
        if let season = store.nextSeasonToWatch(show) {
            await loadSeason(showID: show.id, seasonNumber: season.seasonNumber)
        }
        store.reconcileMembership(show, episodesBySeason: seasonEpisodes)
    }

    // Hydrated episodes stay on screen while a stale season refetches, so a failure offline leaves
    // the cached roster in place.
    func loadSeason(showID: Int, seasonNumber: Int) async {
        guard !loadingSeasons.contains(seasonNumber) else { return }
        if seasonEpisodes[seasonNumber] != nil,
           await MediaCacheStore.shared.isSeasonFresh(showID: showID, seasonNumber: seasonNumber,
                                                     ttl: MediaCacheStore.seasonRefreshTTL) {
            return
        }
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

    private func hydrateEpisodes(from show: Show) {
        for season in show.seasons where !season.episodes.isEmpty {
            seasonEpisodes[season.seasonNumber] = season.episodes
            if !season.cast.isEmpty { seasonCast[season.seasonNumber] = season.cast }
        }
    }

    // A season that has since grown must be re-fetched; the fresh show payload carries the current count.
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
    static func preview(_ show: Show, recommendations: [Show] = [], tint: Color = .appAccent,
                        extras: TitleExtras = .preview) -> ShowDetailModel {
        let model = ShowDetailModel()
        model.show = show
        model.show?.isFullDetail = true      // previews stand in for a landed payload
        model.recommendations = recommendations
        model.tint = tint
        model.extras = extras
        for season in show.seasons {
            model.seasonEpisodes[season.seasonNumber] = season.episodes
        }
        model.loaded = true
        return model
    }

    static func previewPending(_ seed: Show) -> ShowDetailModel {
        let model = ShowDetailModel(seed: seed)
        model.loaded = true
        return model
    }
}

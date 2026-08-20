//
//  MovieDetailModel.swift
//  MovieTracker
//

import SwiftUI

@MainActor
@Observable
final class MovieDetailModel {
    private(set) var movie: Movie?
    private(set) var tint: Color = .appAccent
    private(set) var recommendations: [Movie] = []
    private(set) var collection: [Movie] = []
    private(set) var extras = TitleExtras()

    private let posterPath: String?
    private var loaded = false
    private var loading = false

    init(seed: Movie? = nil) {
        posterPath = seed?.poster
        if let cached = MediaMemoryCache.movie(id: seed?.id) {
            movie = cached.movie
            if let color = cached.tint { tint = color }
        } else {
            movie = seed
            if let color = PosterTint.cached(forPath: posterPath) { tint = color }
        }
    }

    func load(id: Int) async {
        guard !loaded, !loading else { return }
        loading = true
        defer { loading = false }

        // Both requests go out at once. Deriving the tint from the detail payload's poster
        // instead made it land a beat after the page opened, as a visible colour flip.
        async let posterTint = PosterTint.resolve(forPath: posterPath)
        async let detail = Self.fetchDetail(id: id)

        // Cached content renders as itself. Whether it counts as an answer is carried by the record's
        // `isFullDetail`, not decided here.
        if let cached = await MediaCacheStore.shared.load(id: id) {
            if let color = cached.color { tint = color }
            movie = cached.movie
            MediaMemoryCache.store(cached.movie, tint: cached.color)
        }
        if let color = await posterTint { apply(color) }

        // A dropped request must not count as loaded, or the next pass skips the retry and the
        // page sits on the caller's stub for good.
        var interrupted = false

        do {
            let full = try await detail
            let freshTint = await PosterTint.resolve(forPath: full.poster) ?? tint
            tint = freshTint
            movie = full
            MediaMemoryCache.store(full, tint: freshTint)
            await MediaCacheStore.shared.save(full, tint: freshTint)
        } catch {
            // Nothing settles: a failed fetch leaves the fields standing in rather than
            // reporting them empty, and `loaded` stays false so the next pass tries again.
            print("Movie detail load error: \(error)")
            interrupted = true
        }

        // Wikidata is a second service; it resolves alongside the rest of the page rather
        // than holding up the collection and recommendation rows behind it.
        async let resolvedExtras = Self.resolveExtras(for: movie)

        if let franchise = movie?.collection {
            do {
                collection = try await TMDBWrapper.getCollection(id: franchise.id)
                    .filter { $0.id != id }
            } catch {
                print("Movie collection load error: \(error)")
                interrupted = interrupted || error.isCancellation
            }
        }

        do {
            let page = try await TMDBWrapper.movieRecommendations(id: id)
            recommendations = page.items.filter { $0.id != id }
        } catch {
            print("Movie recommendations load error: \(error)")
            interrupted = interrupted || error.isCancellation
        }

        extras = await resolvedExtras

        loaded = !interrupted
    }

    // `nonisolated` so the SPARQL response decodes off the main actor. A failure here is not load-bearing.
    nonisolated private static func resolveExtras(for movie: Movie?) async -> TitleExtras {
        guard let movie else { return TitleExtras() }
        let imdb = ExternalLink.imdb(id: movie.imdbID)

        guard let qid = movie.wikidataID else {
            return TitleExtras(links: [
                .rottenTomatoes(slug: nil, title: movie.title), imdb,
            ].compactMap { $0 }, resolved: true)
        }

        async let awardsTask = WikidataWrapper.awards(qid: qid)
        async let slugTask = WikidataWrapper.rottenTomatoesID(qid: qid)
        let digest = (try? await awardsTask) ?? AwardsDigest()
        let slug = (try? await slugTask) ?? nil

        return TitleExtras(awards: digest, links: [
            .rottenTomatoes(slug: slug, title: movie.title), imdb,
        ].compactMap { $0 }, resolved: true)
    }

    private static func fetchDetail(id: Int) async throws -> Movie {
        if let delay = UITestHooks.detailDelay { try? await Task.sleep(for: delay) }
        return try await TMDBWrapper.getMovie(id: id)
    }

    // Assigned plainly where it lands with `movie`, or SwiftUI folds the payload's layout changes
    // into the same animation.
    private func apply(_ color: Color) {
        guard color != tint else { return }
        withAnimation(.easeInOut) { tint = color }
    }
}

// MARK: - Previews

extension MovieDetailModel {
    static func preview(_ movie: Movie, collection: [Movie] = [], recommendations: [Movie] = [],
                        tint: Color = .appAccent,
                        extras: TitleExtras = .preview) -> MovieDetailModel {
        let model = MovieDetailModel()
        model.movie = movie
        model.movie?.isFullDetail = true      // previews stand in for a landed payload
        model.collection = collection
        model.recommendations = recommendations
        model.tint = tint
        model.extras = extras
        model.loaded = true
        return model
    }

    static func previewPending(_ seed: Movie) -> MovieDetailModel {
        let model = MovieDetailModel(seed: seed)
        model.loaded = true
        return model
    }
}

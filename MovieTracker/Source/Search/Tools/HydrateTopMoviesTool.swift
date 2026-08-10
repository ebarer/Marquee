//
//  HydrateTopMoviesTool.swift
//  MovieTracker
//
//  Fetches detail (collection + cast) for the top-ranked movies in ONE fan-out, so
//  the franchise and cast tools read from `context.movieDetails` instead of each
//  issuing their own per-movie round-trip. Runs after RankMoviesTool.
//

import Foundation

struct HydrateTopMoviesTool: SearchTool {
    var depth = 8

    func apply(to context: SearchContext, using provider: SearchProvider) async -> SearchContext {
        var context = context
        let top = context.movies.prefix(depth)
        guard !top.isEmpty else { return context }

        let details = await withTaskGroup(of: (Int, Movie?).self) { group in
            for movie in top {
                group.addTask { (movie.id, await provider.movieDetail(id: movie.id)) }
            }
            var map: [Int: Movie] = [:]
            for await (id, detail) in group { if let detail { map[id] = detail } }
            return map
        }
        context.movieDetails = details
        return context
    }
}

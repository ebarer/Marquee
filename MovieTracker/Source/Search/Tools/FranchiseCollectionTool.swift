//
//  FranchiseCollectionTool.swift
//  MovieTracker
//
//  Merges in franchise siblings of the notable title matches, so no franchise is hardcoded.
//

import Foundation

struct FranchiseCollectionTool: SearchTool {
    var seedMinVotes = 2_000
    var seedDepth = 5
    var maxSiblingsPerCollection = 12

    func apply(to context: SearchContext, using provider: SearchProvider) async -> SearchContext {
        var context = context

        let seeds = context.movies
            .filter {
                ($0.voteCount ?? 0) >= seedMinVotes
                    && SearchMatching.titleRelevance($0.title, normalizedQuery: context.needle) <= 2
            }
            .sorted { ($0.voteCount ?? 0) > ($1.voteCount ?? 0) }
            .prefix(seedDepth)
        guard !seeds.isEmpty else { return context }

        let collections = await withTaskGroup(of: (id: Int, relevance: Int)?.self) { group in
            for movie in seeds {
                let hydrated = context.movieDetails[movie.id]
                let relevance = SearchMatching.titleRelevance(movie.title,
                                                              normalizedQuery: context.needle)
                group.addTask {
                    if let known = (hydrated ?? movie).collection?.id { return (known, relevance) }
                    guard let id = await provider.movieDetail(id: movie.id)?.collection?.id
                    else { return nil }
                    return (id, relevance)
                }
            }
            var strongest: [Int: Int] = [:]
            for await result in group {
                guard let (id, relevance) = result else { continue }
                strongest[id] = min(strongest[id] ?? relevance, relevance)
            }
            return strongest
        }
        guard !collections.isEmpty else { return context }

        var seen = Set(context.movies.map(\.id))
        for (id, relevance) in collections {
            for movie in await provider.collection(id: id).prefix(maxSiblingsPerCollection)
            where seen.insert(movie.id).inserted {
                context.movies.append(movie)
                context.relatedMovies[movie.id] = relevance
            }
        }
        return context
    }
}

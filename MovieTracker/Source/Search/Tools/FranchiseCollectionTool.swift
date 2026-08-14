//
//  FranchiseCollectionTool.swift
//  MovieTracker
//
//  Surfaces popular related films a title search misses because their titles don't
//  contain the query — "The Dark Knight" for "batman", "Man of Steel" for "superman".
//  The general rule, no hardcoded franchises: take the notable movies that DO match
//  the title, look up the collection each belongs to, and merge in its siblings.
//  ("Batman Begins" → The Dark Knight Collection; "Batman v Superman" → Man of Steel
//  Collection.) Collection ids come from HydrateTopMoviesTool's shared detail fetch.
//  Siblings rank as matches of their seed's strength.
//

import Foundation

struct FranchiseCollectionTool: SearchTool {
    /// Only expand notable title matches, so we chase real franchise entries, not noise.
    var seedMinVotes = 2_000
    var seedDepth = 5
    var maxSiblingsPerCollection = 12

    func apply(to context: SearchContext, using provider: SearchProvider) async -> SearchContext {
        var context = context

        // Seeds: the strongest title matches (exact/prefix/word-start) that are notable,
        // top few by vote count.
        let seeds = context.movies
            .filter {
                ($0.voteCount ?? 0) >= seedMinVotes
                    && SearchMatching.titleRelevance($0.title, normalizedQuery: context.needle) <= 2
            }
            .sorted { ($0.voteCount ?? 0) > ($1.voteCount ?? 0) }
            .prefix(seedDepth)
        guard !seeds.isEmpty else { return context }

        // Collection each seed belongs to, tagged with how strongly the query matched that
        // seed — from the shared hydration cache, else a detail fetch for what it missed.
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

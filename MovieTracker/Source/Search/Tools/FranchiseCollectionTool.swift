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
//  Siblings are flagged related so ranking treats them as strong matches.
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

        // Collection each seed belongs to — from the shared hydration cache, falling
        // back to a detail fetch only for seeds it didn't cover.
        let collectionIDs = await withTaskGroup(of: Int?.self) { group in
            for movie in seeds {
                let hydrated = context.movieDetails[movie.id]
                group.addTask {
                    if let known = (hydrated ?? movie).collection?.id { return known }
                    return await provider.movieDetail(id: movie.id)?.collection?.id
                }
            }
            var ids = Set<Int>()
            for await id in group { if let id { ids.insert(id) } }
            return ids
        }
        guard !collectionIDs.isEmpty else { return context }

        var seen = Set(context.movies.map(\.id))
        for id in collectionIDs {
            for movie in await provider.collection(id: id).prefix(maxSiblingsPerCollection)
            where seen.insert(movie.id).inserted {
                context.movies.append(movie)
                context.relatedMovieIDs.insert(movie.id)  // rank as a strong match
            }
        }
        return context
    }
}

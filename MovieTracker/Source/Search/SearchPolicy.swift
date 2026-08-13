//
//  SearchPolicy.swift
//  MovieTracker
//
//  Declares how a search runs: fetch the base movie/TV/people hits, apply an
//  ordered set of SearchTools that augment them, then interlace movies + TV into
//  the ranked list the UI shows. New behaviour = add/adjust a tool here, not
//  thread another special case through the model.
//

import Foundation

struct SearchPolicy: Sendable {
    struct Ranking: Sendable {
        /// An item below both floors is "obscure" and sinks beneath the notable pool.
        var voteFloor: Int = 100
        var popularityFloor: Double = 5
    }

    var tools: [SearchTool]
    var ranking: Ranking

    func run(query rawQuery: String, using provider: SearchProvider) async -> SearchResults {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return .empty }

        // Each side degrades to empty on its own, so one endpoint's failure never
        // discards another's results.
        async let movies = provider.movies(matching: query)
        async let shows = provider.shows(matching: query)
        async let people = provider.people(matching: query)
        async let benchmark = provider.popularityBenchmark()

        var context = SearchContext(query: query, movies: await movies,
                                    shows: await shows, namedPeople: await people)
        for tool in tools {
            context = await tool.apply(to: context, using: provider)
        }

        let results = SearchMatching.interlaced(movies: context.movies, shows: context.shows,
                                                query: query, voteFloor: ranking.voteFloor,
                                                popularityFloor: ranking.popularityFloor,
                                                relatedMovieIDs: context.relatedMovieIDs,
                                                leadPopularityFloor: await benchmark ?? .infinity)
        return SearchResults(movies: context.movies, shows: context.shows, results: results,
                             namedPeople: context.namedPeople, castPeople: context.castPeople)
    }

    /// The default pipeline. Order matters: variants augment the movie set, then rank it, then
    /// hydrate the top movies ONCE so the franchise and cast tools reuse that single fan-out.
    static let standard = SearchPolicy(
        tools: [
            SpellingVariantTool(),
            RankMoviesTool(),
            HydrateTopMoviesTool(),
            FranchiseCollectionTool(),
            ShowFilterTool(),
            CastPeopleTool(),
        ],
        ranking: Ranking()
    )
}

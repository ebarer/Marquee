//
//  SearchPolicy.swift
//  MovieTracker
//
//  Declares how a search runs: fetch base hits, apply an ordered set of tools, then interlace.
//

import Foundation

struct SearchPolicy: Sendable {
    struct Ranking: Sendable {
        var voteFloor: Int = 100
    }

    var tools: [SearchTool]
    var ranking: Ranking

    func run(query rawQuery: String, using provider: SearchProvider) async -> SearchResults {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return .empty }

        // Each side degrades to empty on its own, so one endpoint's failure never discards another's results.
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
                                                relatedMovies: context.relatedMovies,
                                                popularityBenchmark: await benchmark ?? .infinity,
                                                titleAliases: context.titleAliases)
        return SearchResults(movies: context.movies, shows: context.shows, results: results,
                             namedPeople: context.namedPeople,
                             castPeople: castPeople(context, results: results))
    }

    private func castPeople(_ context: SearchContext, results: [MediaRef]) -> [Person] {
        let leadingFilmID = results.first { $0.isMovie }.flatMap { ref -> Int? in
            guard case .movie(let movie) = ref else { return nil }
            return movie.id
        }
        let promoted = leadingFilmID.flatMap { context.leadsByFilmID[$0] } ?? []
        let filmPeople = context.filmCharacterPeople + promoted
            + context.filmLeads.flatMap(\.people)

        let showLeads = results.first?.isMovie == false
        var seen = Set<Int>()
        return (showLeads ? context.showCastPeople + filmPeople : filmPeople + context.showCastPeople)
            .filter { seen.insert($0.id).inserted }
    }

    // Order matters: variants augment the movie set, then rank it, then hydrate the top movies once
    // so the franchise and cast tools share that single fan-out.
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

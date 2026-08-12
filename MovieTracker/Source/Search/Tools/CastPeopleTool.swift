//
//  CastPeopleTool.swift
//  MovieTracker
//
//  Surfaces people from the matched titles — cast credited as the searched
//  character (or the top film's leads), plus the top show's recurring cast — so
//  the People strip mirrors how a film/show surfaces its cast. Cast comes from
//  HydrateTopMoviesTool's shared detail fetch; no extra per-movie round-trip.
//

import Foundation

struct CastPeopleTool: SearchTool {
    var movieDepth = 8
    var topBilledPerFilm = 15
    var minRoleMatchLength = 4
    var minLeadPrefixLength = 3
    var minCharacterMatchVotes = 300
    var leadFallbackCount = 2
    var leadFallbackMinPopularity = 10.0
    /// A show surfaces its cast only when it's a strong, front-of-results match.
    var showWeakPopularity = 5.0

    func apply(to context: SearchContext, using provider: SearchProvider) async -> SearchContext {
        var context = context
        let fromMovies = await moviePeople(context, using: provider)
        let fromShow = await showPeople(context, using: provider)
        context.castPeople = fromMovies + fromShow
        return context
    }

    private func moviePeople(_ context: SearchContext, using provider: SearchProvider) async -> [Person] {
        guard !context.movies.isEmpty else { return [] }

        // Character-matching needs a non-generic query length; the lead fallback needs an
        // exact title or a qualifying prefix. Skip when neither path could apply.
        let canCharacterMatch = context.needle.count >= minRoleMatchLength
        let canLeadFallback = context.movies.first.map {
            SearchMatching.topFilmLeadsApply(topTitle: $0.title, normalizedQuery: context.needle,
                                             minQueryLength: minLeadPrefixLength)
        } ?? false
        guard canCharacterMatch || canLeadFallback else { return [] }

        let topMovies = Array(context.movies.prefix(movieDepth))
        // Cast from the shared hydration cache; fetch only for any top movie it missed.
        let casts = await withTaskGroup(of: (Int, [Person]).self) { group in
            for (index, movie) in topMovies.enumerated() {
                let hydrated = context.movieDetails[movie.id]
                group.addTask {
                    let detail: Movie?
                    if let hydrated {
                        detail = hydrated
                    } else {
                        detail = await provider.movieDetail(id: movie.id)
                    }
                    return (index, (detail?.team ?? []).filter { $0.type == .Cast })
                }
            }
            var buffer = Array(repeating: [Person](), count: topMovies.count)
            for await (index, cast) in group { buffer[index] = cast }
            return buffer
        }

        let films = zip(topMovies, casts).map { (movie: $0, cast: $1) }
        return SearchMatching.moviePeople(query: context.query,
                                          films: films,
                                          minQueryLength: minRoleMatchLength,
                                          leadPrefixMinLength: minLeadPrefixLength,
                                          topBilledPerFilm: topBilledPerFilm,
                                          minCharacterMatchVotes: minCharacterMatchVotes,
                                          leadFallbackCount: leadFallbackCount,
                                          leadFallbackMinPopularity: leadFallbackMinPopularity)
    }

    private func showPeople(_ context: SearchContext, using provider: SearchProvider) async -> [Person] {
        guard let top = context.shows.first, (top.popularity ?? 0) >= showWeakPopularity else { return [] }
        guard let full = await provider.show(id: top.id) else { return [] }
        return Array(full.recurringCast.prefix(topBilledPerFilm))
    }
}

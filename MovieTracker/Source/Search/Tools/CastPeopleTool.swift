//
//  CastPeopleTool.swift
//  MovieTracker
//
//  Surfaces people from the matched titles, reusing `HydrateTopMoviesTool`'s shared detail fetch.
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
    var showWeakPopularity = 5.0
    // Popularity is a trending number: alone it let a 152-vote 1960s series speak for "avengers".
    var showMinVotes = 300

    func apply(to context: SearchContext, using provider: SearchProvider) async -> SearchContext {
        var context = context
        let films = await namedFilms(context, using: provider)
        context.filmCharacterPeople = SearchMatching.characterMatches(
            films, needle: context.needle, topBilledPerFilm: topBilledPerFilm,
            minVotes: minCharacterMatchVotes)
        context.filmLeads = SearchMatching.filmLeads(
            query: context.query, films: films, leadPrefixMinLength: minLeadPrefixLength,
            topBilledPerFilm: topBilledPerFilm,
            leadFallbackMinPopularity: leadFallbackMinPopularity)
        context.leadsByFilmID = Dictionary(
            films.map { ($0.movie.id, Array($0.cast.prefix(leadFallbackCount))) },
            uniquingKeysWith: { first, _ in first })
        context.showCastPeople = await showPeople(context, using: provider)
        return context
    }

    private func namedFilms(_ context: SearchContext,
                            using provider: SearchProvider) async -> [(movie: Movie, cast: [Person])] {
        guard !context.movies.isEmpty else { return [] }

        // Character matching needs a non-generic query length, the lead fallback an exact title or a
        // qualifying prefix. Skip when neither path could apply.
        let canCharacterMatch = context.needle.count >= minRoleMatchLength
        let canLeadFallback = context.movies.first.map {
            SearchMatching.topFilmLeadsApply(topTitle: $0.title, normalizedQuery: context.needle,
                                             minQueryLength: minLeadPrefixLength)
        } ?? false
        guard canCharacterMatch || canLeadFallback else { return [] }

        let topMovies = Array(context.movies.prefix(movieDepth))
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

        return zip(topMovies, casts).map { (movie: $0, cast: $1) }
    }

    private func showPeople(_ context: SearchContext, using provider: SearchProvider) async -> [Person] {
        guard let top = context.shows.first,
              (top.popularity ?? 0) >= showWeakPopularity,
              (top.voteCount ?? 0) >= showMinVotes else { return [] }
        guard let full = await provider.show(id: top.id) else { return [] }
        return Array(full.recurringCast.prefix(topBilledPerFilm))
    }
}

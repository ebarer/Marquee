//
//  SpellingVariantTool.swift
//  MovieTracker
//
//  TMDB's title search is spelling-sensitive, so re-query alternate spellings and merge the matches.
//

import Foundation

struct SpellingVariantTool: SearchTool {
    // Below this leading popularity, also try the spaced hero variant ("ironman" to "iron man").
    var weakPopularity: Double = 5

    func apply(to context: SearchContext, using provider: SearchProvider) async -> SearchContext {
        var context = context

        var alternates: [String] = []
        if let bullet = SearchMatching.interpunctVariant(of: context.query) {
            alternates.append(bullet)
        }
        if (context.movies.first?.popularity ?? 0) < weakPopularity,
           let spaced = SearchMatching.spacedVariant(of: context.query) {
            alternates.append(spaced)
        }
        guard !alternates.isEmpty else { return context }

        var seen = Set(context.movies.map(\.id))
        for alternate in alternates {
            for movie in await provider.movies(matching: alternate) where seen.insert(movie.id).inserted {
                context.movies.append(movie)
            }
        }
        return context
    }
}

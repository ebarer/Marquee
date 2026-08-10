//
//  SpellingVariantTool.swift
//  MovieTracker
//
//  TMDB's title search is spelling-sensitive: a compressed hero name ("ironman")
//  or a separator title ("wall e") finds only obscure films. This tool re-queries
//  alternate spellings and merges the (more relevant) matches in; noise they add
//  sinks under RankMoviesTool.
//

import Foundation

struct SpellingVariantTool: SearchTool {
    /// Below this leading popularity, the plain query looks weak enough to also try
    /// the spaced hero variant ("ironman" → "iron man").
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

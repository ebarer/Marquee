//
//  RankMoviesTool.swift
//  MovieTracker
//
//  Orders the movie candidates for display, notable films first and low-vote noise sunk.
//

import Foundation

struct RankMoviesTool: SearchTool {
    var minVotes: Int = 100

    func apply(to context: SearchContext, using provider: SearchProvider) async -> SearchContext {
        var context = context
        context.movies = SearchMatching.rankedForDisplay(context.movies, minVotes: minVotes)
        return context
    }
}

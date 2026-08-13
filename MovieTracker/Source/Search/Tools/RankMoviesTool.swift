//
//  RankMoviesTool.swift
//  MovieTracker
//
//  Orders the movie candidates for display — notable films first by popularity,
//  low-vote noise sunk — so downstream cast extraction and interlacing see the
//  strongest matches first. Runs after the movie-augmenting tools.
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

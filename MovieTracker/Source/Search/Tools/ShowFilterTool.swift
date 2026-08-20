//
//  ShowFilterTool.swift
//  MovieTracker
//
//  Trims TMDB's noisy TV relevance to US-aired or exactly-named series, most popular first.
//

import Foundation

struct ShowFilterTool: SearchTool {
    var voteFloor: Int = 10
    var popularityFloor: Double = 5

    func apply(to context: SearchContext, using provider: SearchProvider) async -> SearchContext {
        var context = context
        context.shows = SearchMatching.relevantShows(context.shows, normalizedQuery: context.needle,
                                                     voteFloor: voteFloor, popularityFloor: popularityFloor)
            .sorted { ($0.popularity ?? 0) > ($1.popularity ?? 0) }
        return context
    }
}

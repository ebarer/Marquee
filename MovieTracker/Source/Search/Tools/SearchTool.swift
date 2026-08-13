//
//  SearchTool.swift
//  MovieTracker
//
//  One composable step of a SearchPolicy. A tool augments the working set —
//  fetching more candidates, filtering noise, reordering, or extracting people —
//  and returns the updated context. Order in the policy's tool list is meaningful.
//

import Foundation

protocol SearchTool: Sendable {
    func apply(to context: SearchContext, using provider: SearchProvider) async -> SearchContext
}

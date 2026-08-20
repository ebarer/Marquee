//
//  SearchTool.swift
//  MovieTracker
//

/// One step of a `SearchPolicy`, applied in list order.

import Foundation

protocol SearchTool: Sendable {
    func apply(to context: SearchContext, using provider: SearchProvider) async -> SearchContext
}

//
//  ListRequest.swift
//  MovieTracker
//

import Foundation

/// Which list the Lists screen loads.
enum ListRequest: Sendable, Equatable {
    case list(UUID, sort: ListSortKey, foldOlder: Bool)
    case watched(sort: WatchedSortKey)
    case viewed
}

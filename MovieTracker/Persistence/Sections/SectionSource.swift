//
//  SectionSource.swift
//  MovieTracker
//

import Foundation

/// What a section build reads.
enum SectionSource: Sendable, Equatable {
    case list(UUID, byDateAdded: Bool, foldOlder: Bool)
    case watched(sort: WatchedSortKey)
    case viewed
}

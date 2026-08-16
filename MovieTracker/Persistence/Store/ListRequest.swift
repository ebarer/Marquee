//
//  ListRequest.swift
//  MovieTracker
//

import Foundation

/// Which media types fold their backlog into the collapsed "Older" bucket. Movies go stale once
/// they're out, but working through an old show is normal, so each type folds on its own.
struct OlderFold: OptionSet, Sendable, Hashable {
    let rawValue: Int

    static let movies = OlderFold(rawValue: 1 << 0)
    static let shows = OlderFold(rawValue: 1 << 1)

    func folds(_ type: MediaType) -> Bool {
        switch type {
        case .movie: return contains(.movies)
        case .tv: return contains(.shows)
        }
    }
}

/// Which list the Lists screen loads.
enum ListRequest: Sendable, Equatable {
    case list(UUID, sort: ListSortKey, foldOlder: OlderFold)
    case watched(sort: WatchedSortKey)
    case viewed
}

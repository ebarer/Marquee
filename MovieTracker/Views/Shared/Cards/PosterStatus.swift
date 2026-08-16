//
//  PosterStatus.swift
//  MovieTracker
//

import SwiftUI

/// A title's tracking state as drawn over its poster art.
enum PosterStatus {
    case watched
    /// A series with some — but not all — episodes watched.
    case partial
    case watchList

    var symbol: String {
        switch self {
        case .watched: return "checkmark.circle.fill"
        case .partial: return "circle.tophalf.filled"
        case .watchList: return "bookmark.fill"
        }
    }

    var pointSize: CGFloat {
        switch self {
        case .watched: return 18
        case .partial: return 17
        case .watchList: return 15
        }
    }

    var verticalNudge: CGFloat {
        switch self {
        case .watched: return -1
        case .partial, .watchList: return 0
        }
    }

    /// The badge a movie earns, in precedence order — one rule, so the row and the card can't drift.
    static func derive(movieID: Int, from badges: MediaBadgeIndex) -> PosterStatus? {
        if badges.isWatched(movieID) { return .watched }
        if badges.isInWatchList(movieID) { return .watchList }
        return nil
    }

    /// TV progress is episode-based, so a series reads as watched / partially watched / to-watch
    /// rather than off the movie `watchedAt` flag.
    static func derive(showID: Int, from badges: MediaBadgeIndex) -> PosterStatus? {
        if badges.isShowWatched(showID: showID) { return .watched }
        if badges.hasWatchedEpisodes(showID: showID) { return .partial }
        if badges.isInWatchList(showID, .tv) { return .watchList }
        return nil
    }
}

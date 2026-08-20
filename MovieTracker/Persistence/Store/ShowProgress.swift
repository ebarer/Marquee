//
//  ShowProgress.swift
//  MovieTracker
//

import Foundation

/// A show's tracking state from persisted facts alone; deriving it from `Show.regularSeasons` needs the payload.
struct ShowProgress: Equatable {
    var isWatched = false
    var isCaughtUp = false
    var hasProgress = false
    var isTracked = false
}

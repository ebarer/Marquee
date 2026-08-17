//
//  ShowProgress.swift
//  MovieTracker
//

import Foundation

/// A show's tracking state, answerable from persisted facts alone. Deriving it from
/// `Show.regularSeasons` instead needs the payload, so controls read wrong until it lands.
struct ShowProgress: Equatable {
    var isWatched = false
    var isCaughtUp = false
    var hasProgress = false
    var isTracked = false
}

//
//  ShowProgress.swift
//  MovieTracker
//

import Foundation

/// A show's tracking state, answerable from persisted facts alone. Deriving it from
/// `Show.regularSeasons` instead needs the payload, so controls read wrong until it lands.
struct ShowProgress: Equatable {
    /// Every aired season complete.
    var isWatched = false
    /// Every aired episode watched, but unaired ones remain.
    var isCaughtUp = false
    /// Any watched episode at all.
    var hasProgress = false
    /// On the Watch List.
    var isTracked = false
}

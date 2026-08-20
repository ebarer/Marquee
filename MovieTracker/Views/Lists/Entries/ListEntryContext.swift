//
//  ListEntryContext.swift
//  MovieTracker
//

import SwiftUI

/// Resolved once and passed as values: deriving any of it per entry would re-render on every store tick.
struct ListEntryContext: Equatable {
    let selection: ListSelection
    let isWatchList: Bool
    let watchListIDs: Set<Int>
    let listColor: Color
    var caughtUpShowIDs: Set<Int> = []

    var isViewed: Bool { selection == .viewed }
    var isWatched: Bool { selection == .watched }
    var isCustomList: Bool {
        if case .list = selection { return !isWatchList }
        return false
    }

    func subtitle(for entry: MediaSnapshot) -> String? {
        guard isWatched, let date = entry.dateWatched else { return nil }
        let verb = entry.seasonNumber == nil ? "Watched" : "Finished"
        return "\(verb) \(date.toString())"
    }

    func status(for entry: MediaSnapshot) -> PosterStatus? {
        guard isCustomList else { return nil }
        if entry.dateWatched != nil { return .watched }
        return watchListIDs.contains(entry.tmdbID) ? .watchList : nil
    }

    func rating(for entry: MediaSnapshot) -> Double? {
        (isWatched || (!isWatchList && !isViewed)) ? entry.userRating : nil
    }

    func duration(for entry: MediaSnapshot) -> String? {
        guard isWatchList else { return nil }
        return RuntimeLabel.duration(minutes: entry.runtime)
    }

    func leadingSwipe(for entry: MediaSnapshot) -> ListEntrySwipe? {
        guard entry.mediaType == .tv else { return isWatched ? .addToWatchList : .markWatched }
        // Nothing on a finished season: "add back" reads as confusing there.
        guard !isWatched else { return nil }
        // Caught up: marking stops at today, so every action here would be a no-op.
        guard !caughtUpShowIDs.contains(entry.tmdbID) else { return nil }
        guard let season = entry.seasonNumber else { return .toggleShowWatched }
        // Nothing to mark until the next episode has aired.
        return entry.nextEpisodeDate?.inTheFuture == true ? nil : .trackedSeason(season)
    }
}

enum ListEntrySwipe: Equatable {
    case markWatched
    case addToWatchList
    case trackedSeason(Int)
    case toggleShowWatched
}

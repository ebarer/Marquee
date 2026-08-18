//
//  ListEntryContext.swift
//  MovieTracker
//

import SwiftUI

/// What a list entry needs to know about the selection it's in, resolved once and passed as
/// values: deriving any of it from `MediaList` per entry would re-render on every store tick.
struct ListEntryContext: Equatable {
    let selection: ListSelection
    let isWatchList: Bool
    /// tmdbIDs on the Watch List, for the custom-list poster badge.
    let watchListIDs: Set<Int>
    let listColor: Color

    var isViewed: Bool { selection == .viewed }
    var isWatched: Bool { selection == .watched }
    var isCustomList: Bool {
        if case .list = selection { return !isWatchList }
        return false
    }

    /// The watched date, on the Watched list only. A season is *finished* rather than watched —
    /// the show it belongs to may still be running.
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
        guard isWatchList, let runtime = entry.runtime, runtime > 0 else { return nil }
        return "\(runtime / 60) hr \(runtime % 60) min"
    }

    /// The leading swipe an entry offers, or nil for none.
    func leadingSwipe(for entry: MediaSnapshot) -> ListEntrySwipe? {
        guard entry.mediaType == .tv else { return isWatched ? .addToWatchList : .markWatched }
        // Nothing on a finished season: "add back" reads as confusing there.
        guard !isWatched else { return nil }
        guard let season = entry.seasonNumber else { return .toggleShowWatched }
        // Nothing to mark until the next episode has aired.
        return entry.nextEpisodeDate?.inTheFuture == true ? nil : .trackedSeason(season)
    }
}

/// The leading swipe for one list entry, chosen from the selection rather than the container:
/// the rows and the grid offer the same action.
enum ListEntrySwipe: Equatable {
    case markWatched
    case addToWatchList
    case trackedSeason(Int)
    case toggleShowWatched
}

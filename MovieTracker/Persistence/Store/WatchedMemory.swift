//
//  WatchedMemory.swift
//  MovieTracker
//

import Foundation

/// What un-marking something watched threw away, held for the length of the session so
/// re-marking it restores the date the user entered rather than dating it today.
@MainActor
final class WatchedMemory {
    /// A season carries a rating the snapshot's deletion takes with it, so both come back.
    struct SeasonFacts {
        let watchedAt: Date
        let userRating: Double?
    }

    private struct TitleKey: Hashable {
        let tmdbID: Int
        let mediaTypeRaw: Int
    }

    private struct SeasonKey: Hashable {
        let showID: Int
        let seasonNumber: Int
    }

    private var titles: [TitleKey: Date] = [:]
    private var seasons: [SeasonKey: SeasonFacts] = [:]

    func remember(_ date: Date?, for key: MediaKey) {
        guard let date else { return }
        titles[TitleKey(tmdbID: key.tmdbID, mediaTypeRaw: key.mediaType.rawValue)] = date
    }

    func remember(_ date: Date?, tmdbID: Int, mediaType: MediaType) {
        guard let date else { return }
        titles[TitleKey(tmdbID: tmdbID, mediaTypeRaw: mediaType.rawValue)] = date
    }

    /// Consumed on restore: it becomes the live date, and the next un-mark records it again.
    func takeDate(for key: MediaKey) -> Date? {
        titles.removeValue(forKey: TitleKey(tmdbID: key.tmdbID, mediaTypeRaw: key.mediaType.rawValue))
    }

    func remember(_ season: WatchedSeason) {
        seasons[SeasonKey(showID: season.showTmdbID, seasonNumber: season.seasonNumber)] =
            SeasonFacts(watchedAt: season.watchedAt, userRating: season.userRating)
    }

    func takeSeason(showID: Int, seasonNumber: Int) -> SeasonFacts? {
        seasons.removeValue(forKey: SeasonKey(showID: showID, seasonNumber: seasonNumber))
    }
}

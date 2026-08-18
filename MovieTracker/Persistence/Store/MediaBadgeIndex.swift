//
//  MediaBadgeIndex.swift
//  MovieTracker
//

import Foundation
import SwiftData

/// Every title's badge state in one snapshot, so a row or card resolves its mark with a set
/// lookup. Derived in `body`, the per-title fetches this replaces cost a frame each.
struct MediaBadgeIndex: Sendable {
    struct Key: Hashable, Sendable {
        let tmdbID: Int
        let mediaTypeRaw: Int

        init(_ tmdbID: Int, _ mediaType: MediaType) {
            self.tmdbID = tmdbID
            self.mediaTypeRaw = mediaType.rawValue
        }
    }

    /// A show's season, for the completed-season lookup.
    struct SeasonKey: Hashable, Sendable {
        let showID: Int
        let seasonNumber: Int
    }

    private let watched: Set<Key>
    private let watchList: Set<Key>
    private let showsWatched: Set<Int>
    private let showsCaughtUp: Set<Int>
    private let showsInProgress: Set<Int>
    private let seasonsWatched: Set<SeasonKey>

    /// Empty, for previews and a missing store.
    init() {
        watched = []
        watchList = []
        showsWatched = []
        showsCaughtUp = []
        showsInProgress = []
        seasonsWatched = []
    }

    // Every fetch here names `propertiesToFetch`: materialising whole models to read two columns
    // costs an order of magnitude more, and this runs on the main actor after each save.
    init(context: ModelContext) {
        var items = FetchDescriptor<MediaItem>(
            predicate: #Predicate {
                $0.watchedAt != nil || $0.showWatched == true || $0.showCaughtUp == true
            })
        items.propertiesToFetch = [\.tmdbID, \.mediaTypeRaw, \.watchedAt, \.showWatched,
                                   \.showCaughtUp]
        var watched: Set<Key> = []
        var showsWatched: Set<Int> = []
        var showsCaughtUp: Set<Int> = []
        for item in (try? context.fetch(items)) ?? [] {
            if item.watchedAt != nil { watched.insert(Key(item.tmdbID, item.mediaType)) }
            guard item.mediaType == .tv else { continue }
            if item.showWatched == true { showsWatched.insert(item.tmdbID) }
            if item.showCaughtUp == true { showsCaughtUp.insert(item.tmdbID) }
        }
        self.watched = watched
        self.showsWatched = showsWatched
        self.showsCaughtUp = showsCaughtUp

        if let listID = MediaList.watchList(in: context)?.uuid {
            var entries = FetchDescriptor<ListEntry>(predicate: #Predicate { $0.list?.uuid == listID })
            entries.propertiesToFetch = [\.tmdbID, \.mediaTypeRaw]
            watchList = Set(((try? context.fetch(entries)) ?? []).map { Key($0.tmdbID, $0.mediaType) })
        } else {
            watchList = []
        }

        var episodes = FetchDescriptor<WatchedEpisode>()
        episodes.propertiesToFetch = [\.showTmdbID]
        showsInProgress = Set(((try? context.fetch(episodes)) ?? []).map(\.showTmdbID))

        // A `WatchedSeason` exists exactly while the season is complete, so its presence is
        // the answer — no per-row episode counting.
        var seasons = FetchDescriptor<WatchedSeason>()
        seasons.propertiesToFetch = [\.showTmdbID, \.seasonNumber]
        seasonsWatched = Set(((try? context.fetch(seasons)) ?? [])
            .map { SeasonKey(showID: $0.showTmdbID, seasonNumber: $0.seasonNumber) })
    }

    func isWatched(_ tmdbID: Int, _ mediaType: MediaType = .movie) -> Bool {
        watched.contains(Key(tmdbID, mediaType))
    }

    func isInWatchList(_ tmdbID: Int, _ mediaType: MediaType = .movie) -> Bool {
        watchList.contains(Key(tmdbID, mediaType))
    }

    /// The persisted "every aired season watched" flag, matching `isShowWatchedCached`.
    func isShowWatched(showID: Int) -> Bool { showsWatched.contains(showID) }

    /// Every aired episode watched with unaired ones still to come. Marking stops at today, so
    /// there is nothing left for a mark-watched action to do.
    func isShowCaughtUp(showID: Int) -> Bool { showsCaughtUp.contains(showID) }

    func hasWatchedEpisodes(showID: Int) -> Bool { showsInProgress.contains(showID) }

    func isSeasonWatched(showID: Int, seasonNumber: Int) -> Bool {
        seasonsWatched.contains(SeasonKey(showID: showID, seasonNumber: seasonNumber))
    }
}

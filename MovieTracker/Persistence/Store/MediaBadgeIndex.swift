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

    private let watched: Set<Key>
    private let watchList: Set<Key>
    private let showsWatched: Set<Int>
    private let showsInProgress: Set<Int>

    /// Empty, for previews and a missing store.
    init() {
        watched = []
        watchList = []
        showsWatched = []
        showsInProgress = []
    }

    // Every fetch here names `propertiesToFetch`: materialising whole models to read two columns
    // costs an order of magnitude more, and this runs on the main actor after each save.
    init(context: ModelContext) {
        var items = FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.watchedAt != nil || $0.showWatched == true })
        items.propertiesToFetch = [\.tmdbID, \.mediaTypeRaw, \.watchedAt, \.showWatched]
        var watched: Set<Key> = []
        var showsWatched: Set<Int> = []
        for item in (try? context.fetch(items)) ?? [] {
            if item.watchedAt != nil { watched.insert(Key(item.tmdbID, item.mediaType)) }
            if item.mediaType == .tv, item.showWatched == true { showsWatched.insert(item.tmdbID) }
        }
        self.watched = watched
        self.showsWatched = showsWatched

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
    }

    func isWatched(_ tmdbID: Int, _ mediaType: MediaType = .movie) -> Bool {
        watched.contains(Key(tmdbID, mediaType))
    }

    func isInWatchList(_ tmdbID: Int, _ mediaType: MediaType = .movie) -> Bool {
        watchList.contains(Key(tmdbID, mediaType))
    }

    /// The persisted "every aired season watched" flag, matching `isShowWatchedCached`.
    func isShowWatched(showID: Int) -> Bool { showsWatched.contains(showID) }

    func hasWatchedEpisodes(showID: Int) -> Bool { showsInProgress.contains(showID) }
}

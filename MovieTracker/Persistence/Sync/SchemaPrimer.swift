//
//  SchemaPrimer.swift
//  MovieTracker
//
//  Debug-only CloudKit schema maintenance. Excluded from TestFlight/App Store builds.
//

#if DEBUG
import Foundation
import SwiftData

/// CloudKit materializes a field only when a record writes it, so one populated record per `@Model` primes the schema.
enum SchemaPrimer {
    // Negative so it can't collide with a real TMDB id. Purge once the schema is deployed.
    static let sentinelID = -999_001
    static let sentinelTitle = "CloudKit Schema Primer"

    // Run once from a Debug build signed into iCloud, deploy Development to Production, then `purge`.
    @MainActor
    static func prime(using store: PersistenceCoordinator) {
        let context = store.context
        purge(using: store)
        let now = Date()

        let item = MediaItem(tmdbID: sentinelID, mediaType: .tv, title: sentinelTitle)
        item.posterPath = "/primer.jpg"
        item.releaseDate = now
        item.sortDate = now
        item.runtime = 1
        item.userRating = 0.5
        item.watchedAt = now
        item.lastViewedAt = now
        item.showWatched = true
        item.showCaughtUp = true
        item.watchListOptOut = true
        context.insert(item)

        // Marked de-duplicated to keep it out of `MediaList.all`, which filters those. The pruner
        // collects only watch lists, so this one survives.
        let list = MediaList(name: sentinelTitle, symbol: "ladybug", sortOrder: 0, colorIndex: 1)
        list.customColorHex = "#FF00FF"
        list.sortAscending = false
        list.sortKey = .dateAdded
        list.deduplicatedDate = now
        context.insert(list)

        let entry = ListEntry(key: MediaKey(tmdbID: sentinelID, mediaType: .tv, title: sentinelTitle,
                                           posterPath: "/primer.jpg", releaseDate: now,
                                           runtime: 1, sortDate: now))
        entry.list = list
        context.insert(entry)

        context.insert(WatchedEpisode(showTmdbID: sentinelID, seasonNumber: 1,
                                      episodeNumber: 1, watchedAt: now))

        let season = WatchedSeason(showTmdbID: sentinelID, seasonNumber: 1, showName: sentinelTitle,
                                   seasonName: "Season 1", posterPath: "/primer.jpg",
                                   airDate: now, episodeCount: 1, watchedAt: now)
        season.userRating = 0.5
        context.insert(season)

        context.insert(TrackedSeason(showTmdbID: sentinelID, seasonNumber: 1,
                                     showName: sentinelTitle, posterPath: "/primer.jpg",
                                     episodeCount: 1, nextEpisodeDate: now))

        store.save()
        SyncLog.logger.log("🧪 schema primer written — await export, deploy Dev→Production, then purge")
        SyncLog.snapshot("after prime", in: context)
    }

    @MainActor
    static func isPrimed(using store: PersistenceCoordinator) -> Bool {
        let id = sentinelID
        var descriptor = FetchDescriptor<WatchedEpisode>(predicate: #Predicate { $0.showTmdbID == id })
        descriptor.fetchLimit = 1
        return !fetch(descriptor, store.context).isEmpty
    }

    @MainActor
    static func purge(using store: PersistenceCoordinator) {
        let context = store.context
        let id = sentinelID
        let name = sentinelTitle

        // Deleting the list cascades to its entry; the rest are keyed by the sentinel id.
        for list in fetch(FetchDescriptor<MediaList>(predicate: #Predicate { $0.name == name }), context) {
            context.delete(list)
        }
        for item in fetch(FetchDescriptor<MediaItem>(predicate: #Predicate { $0.tmdbID == id }), context) {
            context.delete(item)
        }
        for entry in fetch(FetchDescriptor<ListEntry>(predicate: #Predicate { $0.tmdbID == id }), context) {
            context.delete(entry)
        }
        for episode in fetch(FetchDescriptor<WatchedEpisode>(predicate: #Predicate { $0.showTmdbID == id }), context) {
            context.delete(episode)
        }
        for season in fetch(FetchDescriptor<WatchedSeason>(predicate: #Predicate { $0.showTmdbID == id }), context) {
            context.delete(season)
        }
        for tracked in fetch(FetchDescriptor<TrackedSeason>(predicate: #Predicate { $0.showTmdbID == id }), context) {
            context.delete(tracked)
        }
        store.save()
    }

    private static func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>,
                                                  _ context: ModelContext) -> [T] {
        (try? context.fetch(descriptor)) ?? []
    }
}
#endif

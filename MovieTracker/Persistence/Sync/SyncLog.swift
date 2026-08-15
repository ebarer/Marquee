//
//  SyncLog.swift
//  MovieTracker
//
//  Central logging for CloudKit sync and de-duplication (category "CloudKitSync").
//

import Foundation
import SwiftData
import OSLog

enum SyncLog {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Marquee",
                               category: "CloudKitSync")

    static func snapshot(_ label: String, in context: ModelContext) {
        let lists = (try? context.fetch(FetchDescriptor<MediaList>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]))) ?? []
        let entryCount = (try? context.fetchCount(FetchDescriptor<ListEntry>())) ?? -1
        let itemCount = (try? context.fetchCount(FetchDescriptor<MediaItem>())) ?? -1
        logger.log("📚 \(label, privacy: .public): \(lists.count) list(s), \(entryCount) entries, \(itemCount) items")

        // TV progress is three separate record types, so drift there is invisible on the line
        // above — the Watched count is movies + `WatchedSeason`, not entries.
        let episodes = (try? context.fetchCount(FetchDescriptor<WatchedEpisode>())) ?? -1
        let watchedSeasons = (try? context.fetchCount(FetchDescriptor<WatchedSeason>())) ?? -1
        let trackedSeasons = (try? context.fetchCount(FetchDescriptor<TrackedSeason>())) ?? -1
        logger.log("📺 \(label, privacy: .public): \(episodes) watched episode(s), \(watchedSeasons) watched season(s), \(trackedSeasons) tracked season(s)")

        for list in lists {
            let count = list.entries?.count ?? 0
            let kind = list.isWatchList ? "watchList" : "custom"
            let dup = list.isDeduplicated ? " [dup]" : ""
            let uuid = String(list.uuid.uuidString.prefix(8))
            logger.log("   • \(list.name, privacy: .public) \(kind, privacy: .public) uuid=\(uuid, privacy: .public) entries=\(count)\(dup, privacy: .public)")
        }
    }
}

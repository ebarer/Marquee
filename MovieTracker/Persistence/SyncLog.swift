//
//  SyncLog.swift
//  MovieTracker
//
//  Central logging for CloudKit sync and de-duplication. Filter in Console or the
//  Xcode debug console by subsystem (the app's bundle id) and category
//  "CloudKitSync". Values are logged `.public` so they're readable while
//  diagnosing sync on your own devices.
//

import Foundation
import SwiftData
import OSLog

enum SyncLog {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Marquee",
                               category: "CloudKitSync")

    /// Logs a snapshot of the library — one line per list plus item/entry totals —
    /// before/after key moments (seed, import, dedup) to see what CloudKit delivered.
    static func snapshot(_ label: String, in context: ModelContext) {
        let lists = (try? context.fetch(FetchDescriptor<MediaList>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]))) ?? []
        let entryCount = (try? context.fetchCount(FetchDescriptor<ListEntry>())) ?? -1
        let itemCount = (try? context.fetchCount(FetchDescriptor<MediaItem>())) ?? -1
        logger.log("📚 \(label, privacy: .public): \(lists.count) list(s), \(entryCount) entries, \(itemCount) items")
        for list in lists {
            let count = list.entries?.count ?? 0
            let kind = list.isWatchList ? "watchList" : "custom"
            let dup = list.isDeduplicated ? " [dup]" : ""
            let uuid = String(list.uuid.uuidString.prefix(8))
            logger.log("   • \(list.name, privacy: .public) \(kind, privacy: .public) uuid=\(uuid, privacy: .public) entries=\(count)\(dup, privacy: .public)")
        }
    }
}

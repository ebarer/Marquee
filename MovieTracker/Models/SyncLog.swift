//
//  SyncLog.swift
//  MovieTracker
//
//  Central logging for CloudKit sync and list de-duplication. Filter in Console
//  or the Xcode debug console by subsystem (the app's bundle id) and category
//  "CloudKitSync". Values are logged `.public` so they're readable while
//  diagnosing sync on your own devices.
//

import Foundation
import SwiftData
import OSLog

enum SyncLog {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MovieTracker",
                               category: "CloudKitSync")

    /// Logs a one-line-per-list snapshot of the whole library: kind, short UUID,
    /// entry count, and whether it's a duplicate awaiting cleanup. Use before/after
    /// key moments (seed, import, dedup) to see exactly what CloudKit delivered.
    static func snapshot(_ label: String, in context: ModelContext) {
        let descriptor = FetchDescriptor<MovieList>(
            sortBy: [SortDescriptor(\.kindRaw), SortDescriptor(\.createdAt)]
        )
        let lists = (try? context.fetch(descriptor)) ?? []
        let entryCount = (try? context.fetchCount(FetchDescriptor<WatchListEntry>())) ?? -1
        logger.log("📚 \(label, privacy: .public): \(lists.count) list record(s), \(entryCount) entry record(s)")
        for list in lists {
            let count = list.entries?.count ?? 0
            let dup = list.isDeduplicated ? " [dup]" : ""
            let uuid = String(list.uuid.uuidString.prefix(8))
            logger.log("   • \(list.name, privacy: .public) kind=\(list.kind.rawValue) uuid=\(uuid, privacy: .public) entries=\(count)\(dup, privacy: .public)")
        }
    }
}

//
//  PersistenceCoordinator+Lifecycle.swift
//  MovieTracker
//

import Foundation
import SwiftData

extension PersistenceCoordinator {

    // MARK: - Maintenance (launch)

    func seedWatchList() { _ = watchList; save() }

    /// Converges duplicate Watch Lists, list entries, MediaItems, and TV-progress records a
    /// CloudKit import produced.
    func deduplicate() {
        MediaList.deduplicateWatchList(in: context)
        // After the merge, so entries re-parented onto the surviving list get collapsed too.
        MediaList.deduplicateEntries(in: context)
        MediaItem.deduplicate(in: context)
        WatchedEpisode.deduplicate(in: context)
        WatchedSeason.deduplicate(in: context)
        TrackedSeason.deduplicate(in: context)
        save()
    }

    func bootstrap() async {
        // The driving `.task` can re-fire (e.g. a size-class change at launch);
        // run the launch sequence — and start only one remote-change loop — once.
        guard claimLaunchRoutine() else {
            SyncLog.logger.log("🌱 bootstrap already ran — skipping duplicate launch task")
            return
        }
        SyncLog.snapshot("launch", in: context)

        // Fresh local store: wait for the Watch List to sync before seeding, so we
        // adopt the existing list instead of creating a duplicate.
        if MediaList.watchList(in: context) == nil {
            SyncLog.logger.log("🌱 empty local store — waiting up to 6s for the Watch List to sync before seeding")
            let arrived = await waitForWatchList(timeout: .seconds(6))
            SyncLog.logger.log("🌱 wait ended (\(arrived ? "Watch List arrived" : "timed out — seeding", privacy: .public))")
        } else {
            SyncLog.logger.log("🌱 existing local store — seeding/reconciling immediately")
        }
        seedWatchList()
        deduplicate()
        SyncLog.snapshot("after seed", in: context)

        let targets = MediaCachePlan.local(in: context)
        Task.detached(priority: .utility) {
            await MediaCachePrefetcher.prefetch(targets)
        }
        // Poll in-progress shows for newly-aired seasons (reconciles on the main actor).
        Task { await self.refreshWatchedShows() }

        await observeRemoteChanges {
            SyncLog.logger.log("🔁 remote change settled — reconciling")
            self.deduplicate()
            SyncLog.snapshot("after reconcile", in: self.context)
        }
    }

    /// Polls for the Watch List: CloudKit imports the whole zone with no per-type
    /// ordering, so there's nothing to prioritize — we just wait for the one record.
    private func waitForWatchList(timeout: Duration) async -> Bool {
        let start = ContinuousClock.now
        while ContinuousClock.now - start < timeout {
            if MediaList.watchList(in: context) != nil { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return MediaList.watchList(in: context) != nil
    }
}

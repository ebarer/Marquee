//
//  PersistenceCoordinator+Lifecycle.swift
//  MovieTracker
//
//  App launch orchestration and CloudKit reconciliation: seeds the built-in Watch
//  List, converges duplicates a CloudKit import produced, and keeps reconciling as
//  remote changes land. This is the MovieTracker-specific startup that builds on the
//  general plumbing (save, revision, remote-change observation) in `PersistenceCoordinator`.
//

import Foundation
import SwiftData

extension PersistenceCoordinator {

    // MARK: - Maintenance (launch)

    /// Seeds the Watch List at launch.
    func seedWatchList() { _ = watchList; save() }

    /// Converges duplicate Watch Lists and MediaItems a CloudKit import produced.
    func deduplicate() {
        MediaList.deduplicateWatchList(in: context)
        MediaItem.deduplicate(in: context)
        save()
    }

    /// Runs the launch sequence and then keeps reconciling for the lifetime of the
    /// scene: on a fresh store it waits for the Watch List to sync before seeding
    /// (so it adopts the existing list instead of creating a duplicate), seeds and
    /// deduplicates, then reconciles again whenever CloudKit imports settle.
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
        // Prune any duplicates a prior session marked (past the grace period).
        deduplicate()
        SyncLog.snapshot("after seed", in: context)

        // Pre-cache saved titles for offline use, off the main path.
        let ids = savedMovieIDs()
        Task.detached(priority: .utility) {
            await MediaCachePrefetcher.prefetch(ids: ids)
        }

        // Reconcile built-in lists whenever CloudKit remote changes settle.
        await observeRemoteChanges {
            SyncLog.logger.log("🔁 remote change settled — reconciling")
            self.deduplicate()
            SyncLog.snapshot("after reconcile", in: self.context)
        }
    }

    /// Polls up to `timeout` for the Watch List to sync down, so a fresh device
    /// adopts the existing list instead of seeding a duplicate. Returns `true` if it
    /// arrived. We poll because CloudKit imports the whole zone with no per-type
    /// ordering — there's nothing to prioritize, so we just wait for the one record.
    private func waitForWatchList(timeout: Duration) async -> Bool {
        let start = ContinuousClock.now
        while ContinuousClock.now - start < timeout {
            if MediaList.watchList(in: context) != nil { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return MediaList.watchList(in: context) != nil
    }
}

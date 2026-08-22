//
//  PersistenceCoordinator+Lifecycle.swift
//  MovieTracker
//

import Foundation
import SwiftData

extension PersistenceCoordinator {

    // MARK: - Maintenance (launch)

    func seedWatchList() { _ = watchList; save() }

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
        // The driving `.task` can re-fire, as on a size-class change at launch, so run the sequence once.
        guard claimLaunchRoutine() else {
            SyncLog.logger.log("🌱 bootstrap already ran — skipping duplicate launch task")
            return
        }
        SyncLog.snapshot("launch", in: context)

        // Fresh local store: wait for the Watch List to sync before seeding, or a duplicate is created.
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
        Task { await self.refreshWatchedShows() }
        Task {
            await self.repairBulkMarkedWatchDates()
            await self.rescheduleEpisodeReminders()
        }

        await observeRemoteChanges {
            SyncLog.logger.log("🔁 remote change settled — reconciling")
            self.deduplicate()
            SyncLog.snapshot("after reconcile", in: self.context)
        }
    }

    // Air dates get revised, so the batch is rebuilt each launch rather than trusted once scheduled.
    func rescheduleEpisodeReminders() async {
        guard NotificationSettings.shared.isEnabled else { return }
        await EpisodeNotificationScheduler.reschedule(await episodeReminders())
    }

    // CloudKit imports the whole zone with no per-type ordering, so there is nothing to do but wait.
    private func waitForWatchList(timeout: Duration) async -> Bool {
        let start = ContinuousClock.now
        while ContinuousClock.now - start < timeout {
            if MediaList.watchList(in: context) != nil { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return MediaList.watchList(in: context) != nil
    }
}

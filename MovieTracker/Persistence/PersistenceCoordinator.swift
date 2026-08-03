//
//  PersistenceCoordinator.swift
//  MovieTracker
//

import SwiftUI
import SwiftData
import CoreData

/// The single writer for the SwiftData store. Every mutation runs on the main
/// actor and persists immediately, so the Lists views reflect changes at once
/// (rather than waiting on autosave) and nothing is lost on a crash. Domain logic
/// lives on the models; this coordinates applying it and saving. Heavy reads and
/// grouping stay on the background `SectionBuilder`.
///
/// The domain surface is split across `PersistenceCoordinator+Lists` (lists and
/// membership) and `PersistenceCoordinator+Media` (per-title facts); this file
/// holds the shared plumbing and the launch/maintenance lifecycle.
@MainActor
@Observable
final class PersistenceCoordinator {
    let context: ModelContext

    /// Increments on every persisted change — a local save or a CloudKit import.
    /// Views observe this instead of subscribing to store notifications themselves,
    /// so a mutation that doesn't alter a `@Query` (e.g. a watched-date edit) still
    /// drives a refresh.
    private(set) var revision = 0

    init(_ context: ModelContext) {
        self.context = context
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
            revision &+= 1
        } catch {
            SyncLog.logger.error("💾 save failed: \(error, privacy: .public)")
        }
    }

    /// Applies a mutation and persists it. Prefer the typed helpers; use this for
    /// one-off changes that don't warrant their own method.
    func perform(_ mutation: () -> Void) {
        mutation()
        save()
    }

    /// The backing container, for the background `SectionBuilder`. Views reach the
    /// coordinator, never the raw `ModelContext`.
    var container: ModelContainer { context.container }

    func insert(_ model: any PersistentModel) { context.insert(model); save() }
    func delete(_ model: any PersistentModel) { context.delete(model); save() }

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

        await reconcileOnRemoteChanges()
    }

    /// Reconciles built-in lists whenever CloudKit remote changes land, debounced
    /// so we act once a burst of imported records settles. Never returns.
    private func reconcileOnRemoteChanges() async {
        var debounce: Task<Void, Never>?
        for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
            revision &+= 1   // a CloudKit import landed — nudge observers to refresh
            debounce?.cancel()
            debounce = Task {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                SyncLog.logger.log("🔁 remote change settled — reconciling")
                self.deduplicate()
                SyncLog.snapshot("after reconcile", in: self.context)
            }
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

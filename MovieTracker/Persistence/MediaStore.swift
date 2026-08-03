//
//  MediaStore.swift
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
@MainActor
@Observable
final class MediaStore {
    let context: ModelContext

    init(_ context: ModelContext) {
        self.context = context
    }

    /// The Watch List, lazily created if it doesn't exist yet. The single place
    /// that lazy-creation happens — callers just express intent (add/remove/toggle).
    var watchList: MediaList { MediaList.ensureWatchList(in: context) }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            SyncLog.logger.error("💾 save failed: \(error, privacy: .public)")
        }
    }

    /// Applies a mutation and persists it. Prefer the typed helpers below; use this
    /// for one-off changes that don't warrant their own method.
    func perform(_ mutation: () -> Void) {
        mutation()
        save()
    }

    /// The backing container, for the background `SectionBuilder`. Views reach the
    /// store, never the raw `ModelContext`.
    var container: ModelContainer { context.container }

    // MARK: - Reads (so views never touch the context)

    func isWatched(_ movie: Movie) -> Bool { MediaItem.isWatched(movie, in: context) }
    func rating(for movie: Movie) -> Double? { MediaItem.rating(for: movie, in: context) }
    func dateWatched(for movie: Movie) -> Date? { MediaItem.dateWatched(for: movie, in: context) }

    var watchedCount: Int {
        (try? context.fetchCount(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.watchedAt != nil }))) ?? 0
    }
    var viewedCount: Int {
        (try? context.fetchCount(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.lastViewedAt != nil }))) ?? 0
    }

    // MARK: - Lists (the coordinator owns which lists are canonical)

    /// Every canonical list in display order (custom lists plus the one Watch List).
    var lists: [MediaList] { MediaList.all(in: context) }
    var customLists: [MediaList] { MediaList.customLists(in: context) }

    /// Collapses a live `@Query` result to the canonical display set — duplicates
    /// dropped and any duplicate Watch List merged to the oldest copy (UUID breaks
    /// ties, matching `watchList`). Screens keep `@Query` for reactivity but defer
    /// the "which copy is canonical" decision to here rather than deciding themselves.
    func canonicalLists(_ lists: [MediaList]) -> [MediaList] {
        let visible = lists.filter { !$0.isDeduplicated }
        guard let watch = visible.filter(\.isWatchList)
            .min(by: { ($0.createdAt, $0.uuid.uuidString) < ($1.createdAt, $1.uuid.uuidString) })
        else { return visible }
        return visible.filter { !$0.isWatchList || $0.uuid == watch.uuid }
    }

    // MARK: - List membership

    func toggle(_ movie: Movie, in list: MediaList) { list.toggle(movie); save() }
    func add(_ movie: Movie, to list: MediaList) { list.add(movie); save() }
    func toggleWatchList(_ movie: Movie) { watchList.toggle(movie); save() }
    func addToWatchList(_ movie: Movie) { watchList.add(movie); save() }

    // MARK: - Title facts

    func setWatched(_ watched: Bool, for movie: Movie) {
        MediaItem.setWatched(watched, for: movie, in: context); save()
    }
    func setRating(_ stars: Double?, for movie: Movie) {
        MediaItem.setRating(stars, for: movie, in: context); save()
    }
    func setDateWatched(_ date: Date?, for movie: Movie) {
        MediaItem.setDateWatched(date, for: movie, in: context); save()
    }
    func recordView(_ movie: Movie) {
        MediaItem.recordView(movie, in: context); save()
    }

    // MARK: - Insert / delete

    func insert(_ model: any PersistentModel) { context.insert(model); save() }
    func delete(_ model: any PersistentModel) { context.delete(model); save() }
    func deleteList(_ list: MediaList) { context.delete(list); save() }

    /// Clears a derived flag (Watched / Viewed) and prunes the item if it's now empty.
    func unwatch(_ item: MediaItem) { item.watchedAt = nil; item.pruneIfEmpty(); save() }
    func removeFromViewed(_ item: MediaItem) { item.lastViewedAt = nil; item.pruneIfEmpty(); save() }

    // Resolve a row snapshot's id back to its live model, so list rows act through
    // the store instead of the context. No-op if the model is already gone.
    func deleteEntry(_ id: PersistentIdentifier) {
        if let entry = context.model(for: id) as? ListEntry { delete(entry) }
    }
    func unwatch(_ id: PersistentIdentifier) {
        if let item = context.model(for: id) as? MediaItem { unwatch(item) }
    }
    func removeFromViewed(_ id: PersistentIdentifier) {
        if let item = context.model(for: id) as? MediaItem { removeFromViewed(item) }
    }

    func clearViewed() {
        let items = (try? context.fetch(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.lastViewedAt != nil }))) ?? []
        for item in items {
            item.lastViewedAt = nil
            item.pruneIfEmpty()
        }
        save()
    }

    /// Snapshots the whole library into a backup archive.
    func exportArchive() -> WatchDataArchive { WatchDataArchive.export(from: context) }

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

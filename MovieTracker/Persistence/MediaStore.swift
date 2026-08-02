//
//  MediaStore.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

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

    // MARK: - Deletions

    func delete(_ model: any PersistentModel) { context.delete(model); save() }
    func deleteList(_ list: MediaList) { context.delete(list); save() }

    /// Clears a derived flag (Watched / Viewed) and prunes the item if it's now empty.
    func unwatch(_ item: MediaItem) { item.watchedAt = nil; item.pruneIfEmpty(); save() }
    func removeFromViewed(_ item: MediaItem) { item.lastViewedAt = nil; item.pruneIfEmpty(); save() }

    func clearViewed() {
        let items = (try? context.fetch(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.lastViewedAt != nil }))) ?? []
        for item in items {
            item.lastViewedAt = nil
            item.pruneIfEmpty()
        }
        save()
    }

    // MARK: - Maintenance (launch)

    /// Seeds the Watch List at launch.
    func seedWatchList() { _ = watchList; save() }

    /// Converges duplicate Watch Lists and MediaItems a CloudKit import produced.
    func deduplicate() {
        MediaList.deduplicateWatchList(in: context)
        MediaItem.deduplicate(in: context)
        save()
    }
}

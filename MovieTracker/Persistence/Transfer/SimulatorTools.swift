//
//  SimulatorTools.swift
//  MovieTracker
//
//  Simulator-only seeding helpers, excluded from device and TestFlight builds.
//

#if targetEnvironment(simulator)
import Foundation
import SwiftData

enum SimulatorTools {
    @MainActor
    static func populate(using store: PersistenceCoordinator,
                         progress: (Int, Int) -> Void = { _, _ in }) async -> ImportSummary? {
        guard let url = Bundle.main.url(forResource: "sample-data", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let archive = try? LibraryBackup(json: data) else {
            return nil
        }
        return await LibraryBackup.merge(archive, using: store, progress: progress)
    }

    @MainActor
    static func reset(using store: PersistenceCoordinator) {
        let context = store.context
        // Deleting lists cascades to their entries; wipe items and any orphans explicitly.
        for list in (try? context.fetch(FetchDescriptor<MediaList>())) ?? [] { context.delete(list) }
        for entry in (try? context.fetch(FetchDescriptor<ListEntry>())) ?? [] { context.delete(entry) }
        for item in (try? context.fetch(FetchDescriptor<MediaItem>())) ?? [] { context.delete(item) }
        for episode in (try? context.fetch(FetchDescriptor<WatchedEpisode>())) ?? [] { context.delete(episode) }
        for season in (try? context.fetch(FetchDescriptor<WatchedSeason>())) ?? [] { context.delete(season) }
        for tracked in (try? context.fetch(FetchDescriptor<TrackedSeason>())) ?? [] { context.delete(tracked) }
        store.save()
        store.seedWatchList()
    }
}
#endif

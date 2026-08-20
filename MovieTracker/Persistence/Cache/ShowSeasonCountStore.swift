//
//  ShowSeasonCountStore.swift
//  MovieTracker
//

import Foundation

/// Session memo for lazily-resolved show details. Deduplicates concurrent/repeat lookups by id.
@MainActor
final class ShowSeasonCountStore {
    static let shared = ShowSeasonCountStore()

    private var resolved: [Int: Show] = [:]
    private var tasks: [Int: Task<Show?, Never>] = [:]

    func show(for id: Int) async -> Show? {
        if let cached = resolved[id] { return cached }
        if let inFlight = tasks[id] { return await inFlight.value }

        let task = Task<Show?, Never> {
            if let cached = await MediaCacheStore.shared.loadShow(id: id), cached.show.seasonCount > 0 {
                return cached.show
            }
            return try? await TMDBWrapper.showSummary(id: id)
        }
        tasks[id] = task
        let result = await task.value
        tasks[id] = nil
        if let result { resolved[id] = result }
        return result
    }
}

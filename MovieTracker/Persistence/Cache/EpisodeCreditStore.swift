//
//  EpisodeCreditStore.swift
//  MovieTracker
//

import Foundation

/// Session memo for `/credit/{id}` lookups. Filmography rows resolve lazily as they scroll,
/// so repeat and concurrent lookups for the same credit have to collapse into one request.
@MainActor
final class EpisodeCreditStore {
    static let shared = EpisodeCreditStore()

    private var resolved: [String: EpisodeCredit] = [:]
    private var tasks: [String: Task<EpisodeCredit?, Never>] = [:]

    /// The merged credit across every id TMDB filed the person under for `show`, or nil
    /// when the show carries no credit ids or none resolve.
    func credit(for show: Show) async -> EpisodeCredit? {
        var parts: [EpisodeCredit] = []
        for id in show.creditIDs {
            if let part = await credit(id: id) { parts.append(part) }
        }
        return EpisodeCredit.merging(parts)
    }

    private func credit(id: String) async -> EpisodeCredit? {
        if let cached = resolved[id] { return cached }
        if let inFlight = tasks[id] { return await inFlight.value }

        let task = Task<EpisodeCredit?, Never> { try? await TMDBWrapper.getCredit(id: id) }
        tasks[id] = task
        let result = await task.value
        tasks[id] = nil
        if let result { resolved[id] = result }
        return result
    }
}

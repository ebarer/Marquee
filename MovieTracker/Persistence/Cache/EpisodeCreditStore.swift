//
//  EpisodeCreditStore.swift
//  MovieTracker
//

import Foundation

/// Session memo for /credit/{id}; repeat and concurrent lookups collapse into one request.
@MainActor
final class EpisodeCreditStore {
    static let shared = EpisodeCreditStore()

    private var resolved: [String: EpisodeCredit] = [:]
    private var tasks: [String: Task<EpisodeCredit?, Never>] = [:]

    func credit(for show: Show) async -> EpisodeCredit? {
        var parts: [EpisodeCredit] = []
        for id in show.creditIDs {
            if let part = await credit(id: id) { parts.append(part) }
        }
        return EpisodeCredit.merging(parts)
    }

    // A roster cached before credit ids were kept carries none, so fall back to the person's own TV credits.
    func credit(person id: Int, in show: Show) async -> EpisodeCredit? {
        guard let person = try? await TMDBWrapper.getPerson(id: id),
              let credit = (person.tvCredits ?? []).first(where: { $0.id == show.id }),
              !credit.creditIDs.isEmpty else { return nil }
        var subject = show
        subject.creditIDs = credit.creditIDs
        return await self.credit(for: subject)
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

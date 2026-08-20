//
//  PersonDetailModel.swift
//  MovieTracker
//

import SwiftUI

@MainActor
@Observable
final class PersonDetailModel {
    private(set) var person: Person?
    private(set) var episodeCredits: [Int: EpisodeCredit] = [:]
    private(set) var isResolvingCredits = false

    private var loaded = false

    func load(id: Int) async {
        guard !loaded else { return }
        loaded = true
        do {
            let person = try await TMDBWrapper.getPerson(id: id)
            self.person = person
            await resolveEpisodeCredits(for: person)
        } catch {
            print("Person detail load error: \(error)")
        }
    }

    // A row's year section is decided before layout, and the season air dates that decide it aren't
    // in the person payload.
    private func resolveEpisodeCredits(for person: Person) async {
        let shows = (person.tvCredits ?? []).filter { !$0.creditIDs.isEmpty }
        guard !shows.isEmpty else { return }

        isResolvingCredits = true
        defer { isResolvingCredits = false }

        var resolved: [Int: EpisodeCredit] = [:]
        await withTaskGroup(of: (Int, EpisodeCredit?).self) { group in
            for show in shows {
                group.addTask { (show.id, await EpisodeCreditStore.shared.credit(for: show)) }
            }
            for await (id, credit) in group {
                resolved[id] = credit
            }
        }
        episodeCredits = resolved.compactMapValues { $0 }
    }

    static func preview(person: Person, episodeCredits: [Int: EpisodeCredit] = [:]) -> PersonDetailModel {
        let model = PersonDetailModel()
        model.person = person
        model.episodeCredits = episodeCredits
        model.loaded = true
        return model
    }
}

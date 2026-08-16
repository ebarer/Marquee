//
//  FilmographyEntry.swift
//  MovieTracker
//

import Foundation

/// One row of a person's filmography. A TV credit becomes an entry per season they were in,
/// so a long run appears under each year it aired rather than only under its premiere.
struct FilmographyEntry: Identifiable, Hashable {
    let ref: MediaRef
    /// The season this entry stands for; nil for a film, or a TV credit with no episode
    /// detail behind it.
    var season: EpisodeCredit.SeasonCredit? = nil
    /// The whole credit behind a TV entry, so opening it doesn't re-resolve what's known.
    var credit: EpisodeCredit? = nil

    var id: String {
        guard let season else { return ref.id }
        return "\(ref.id)-s\(season.season.seasonNumber)"
    }

    /// The season aired where there's a season, else the title's own date.
    var date: Date? { season?.season.airDate ?? ref.date }

    /// Expands credits into rows, newest first: films as they are, a resolved TV credit split
    /// per season. Ties keep their incoming order, which is TMDB's own.
    static func entries(for credits: [MediaRef],
                        episodeCredits: [Int: EpisodeCredit]) -> [FilmographyEntry] {
        credits
            .flatMap { ref -> [FilmographyEntry] in
                guard case .show(let show) = ref,
                      let credit = episodeCredits[show.id],
                      !credit.credited.isEmpty else {
                    return [FilmographyEntry(ref: ref)]
                }
                return credit.credited.map {
                    FilmographyEntry(ref: ref, season: $0, credit: credit)
                }
            }
            .enumerated()
            .sorted { left, right in
                guard let leftDate = left.element.date else { return false }
                guard let rightDate = right.element.date else { return true }
                if leftDate != rightDate { return leftDate > rightDate }
                return left.offset < right.offset
            }
            .map(\.element)
    }
}

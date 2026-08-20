//
//  FilmographyEntry.swift
//  MovieTracker
//

import Foundation

/// One row of a person's filmography; a TV credit becomes one entry per season they were in.
struct FilmographyEntry: Identifiable, Hashable {
    let ref: MediaRef
    var season: EpisodeCredit.SeasonCredit? = nil
    var credit: EpisodeCredit? = nil

    var id: String {
        guard let season else { return ref.id }
        return "\(ref.id)-s\(season.season.seasonNumber)"
    }

    var date: Date? { season?.season.airDate ?? ref.date }

    static func upcoming(in entries: [FilmographyEntry], now: Date = Date()) -> [FilmographyEntry] {
        entries.filter { ($0.date.map { $0 > now }) ?? false }
    }

    // Entries arrive newest-first, so grouping in order preserves that. Undated ones drop out.
    static func byYear(in entries: [FilmographyEntry],
                       now: Date = Date()) -> [(year: Int, entries: [FilmographyEntry])] {
        var groups: [(year: Int, entries: [FilmographyEntry])] = []
        for entry in entries {
            guard let date = entry.date, date <= now else { continue }
            let year = Calendar.current.component(.year, from: date)
            if let index = groups.indices.last, groups[index].year == year {
                groups[index].entries.append(entry)
            } else {
                groups.append((year: year, entries: [entry]))
            }
        }
        return groups
    }

    func matches(query: String) -> Bool {
        ref.title.matches(query: query) || (ref.creditRoleSummary?.matches(query: query) ?? false)
    }

    // Ties keep their incoming order, which is TMDB's.
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

//
//  EpisodeCredit.swift
//  MovieTracker
//

import Foundation

/// A person's credit on one show as TMDB's `/credit` endpoint reports it: which seasons they
/// appear in, and — unless they're in the whole season — which episodes within each.
struct EpisodeCredit: Hashable, Sendable {
    /// Ordered by season number.
    var seasons: [SeasonCredit]

    struct SeasonCredit: Hashable, Sendable {
        let season: Season
        /// An empty set means every episode of the season — TMDB's shape for a regular.
        var episodeNumbers: Set<Int> = []

        /// A season stood up from its episodes alone has no count to compare against, so
        /// only an outright empty set claims the whole run.
        var isWhole: Bool {
            episodeNumbers.isEmpty
                || (season.episodeCount > 0 && episodeNumbers.count >= season.episodeCount)
        }

        var count: Int { isWhole ? season.episodeCount : episodeNumbers.count }

        /// Whether the credit covers `number` within this season.
        func covers(episode number: Int) -> Bool {
            isWhole || episodeNumbers.contains(number)
        }

        var label: String {
            "\(season.name) • \(EpisodeCredit.episodeCountLabel(count))"
        }
    }

    /// How the credit reads in a filmography row.
    enum Summary: Hashable, Sendable {
        /// A one-off appearance, worth naming outright.
        case episode(season: Int, number: Int)
        /// Every episode of a single season.
        case season(Season)
        /// Too many to name — the row offers the episode list instead.
        case spread(Int)
    }

    /// Specials are dropped whenever the person also appears in regular seasons: TMDB's own
    /// episode count does the same, and the app browses shows without season 0.
    var credited: [SeasonCredit] {
        let counted = seasons.filter { $0.count > 0 }
        let regular = counted.filter { !$0.season.isSpecials }
        return regular.isEmpty ? counted : regular
    }

    var total: Int { credited.reduce(0) { $0 + $1.count } }

    var summary: Summary? {
        let credited = self.credited
        guard credited.count == 1, let only = credited.first else {
            return total > 0 ? .spread(total) : nil
        }
        if only.isWhole { return .season(only.season) }
        if only.episodeNumbers.count == 1, let number = only.episodeNumbers.first {
            return .episode(season: only.season.seasonNumber, number: number)
        }
        return .spread(only.count)
    }

    /// True when the credit is best explored as a list rather than by opening the show.
    var needsEpisodeList: Bool {
        if case .spread = summary { return true }
        return false
    }

    /// Folds the credits TMDB files separately for one show (cast and crew, or several
    /// characters) into a single per-season view.
    static func merging(_ parts: [EpisodeCredit]) -> EpisodeCredit? {
        guard !parts.isEmpty else { return nil }
        var bySeason: [Int: SeasonCredit] = [:]
        for credit in parts.flatMap(\.seasons) {
            guard var existing = bySeason[credit.season.seasonNumber] else {
                bySeason[credit.season.seasonNumber] = credit
                continue
            }
            existing.episodeNumbers = existing.isWhole || credit.isWhole
                ? []
                : existing.episodeNumbers.union(credit.episodeNumbers)
            bySeason[credit.season.seasonNumber] = existing
        }
        return EpisodeCredit(seasons: bySeason.values.sorted {
            $0.season.seasonNumber < $1.season.seasonNumber
        })
    }
}

// MARK: - Row text

extension EpisodeCredit.Summary {
    /// The line a filmography row shows in place of the show's year range.
    var label: String {
        switch self {
        case .episode(let season, let number): return "S\(season) · E\(number)"
        case .season(let season):
            return "\(season.name) • \(EpisodeCredit.episodeCountLabel(season.episodeCount))"
        case .spread(let count): return EpisodeCredit.episodeCountLabel(count)
        }
    }
}

extension EpisodeCredit {
    /// The unresolved fallback: TMDB's declared count, shown until (or unless) the
    /// episode-level credit arrives.
    static func episodeCountLabel(_ count: Int) -> String {
        "\(count) Episode\(count == 1 ? "" : "s")"
    }
}

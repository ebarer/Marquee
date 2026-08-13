//
//  Person+KnownFor.swift
//  MovieTracker
//
//  Ranks a person's credits by what they are actually known for.
//

import Foundation

extension Person {
    /// Credits ranked by the title's notability, discounted by how small the part was —
    /// a cameo in a blockbuster out-votes a lead in anything, so votes alone read as noise.
    var knownFor: [MediaRef] {
        let cutoff = Calendar.current.date(byAdding: .month, value: -Self.recentMonths, to: .now)
        func recent(_ date: Date?) -> Bool {
            guard let date, let cutoff else { return false }
            return date >= cutoff
        }

        let films = (credits ?? [])
            .filter { !$0.isExtraneousCredit && $0.poster != nil }
            .map { (ref: MediaRef.movie($0),
                    score: Self.score(votes: $0.voteCount, weight: Self.billingWeight($0.creditOrder),
                                      isRecent: recent($0.releaseDate))) }
        let series = (tvCredits ?? [])
            .filter { !$0.isExtraneousCredit && $0.poster != nil }
            .map { (ref: MediaRef.show($0),
                    score: Self.score(votes: $0.voteCount, weight: Self.castWeight($0.episodeCount),
                                      isRecent: recent($0.firstAirDate))) }

        return (films + series)
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.score != rhs.element.score { return lhs.element.score > rhs.element.score }
                return lhs.offset < rhs.offset
            }
            .map(\.element.ref)
    }

    /// Notability is log-scaled so a 20× vote gap can't swamp the role weighting, then
    /// nudged for recent work — vote counts accrue over years, so new titles under-read.
    private static func score(votes: Int?, weight: Double, isRecent: Bool) -> Double {
        log10(Double(votes ?? 0) + 10) * weight + (isRecent ? recencyBonus : 0)
    }

    /// TMDB's billing order, where the top-billed few share full weight and everything
    /// below decays — the difference between 1st and 4th billing isn't meaningful.
    private static func billingWeight(_ order: Int?) -> Double {
        guard let order else { return crewWeight }
        guard order > topBilled else { return 1 }
        return 1 / (1 + Double(order - topBilled) / billingFalloff)
    }

    /// Episode count stands in for billing on TV: a series regular against a guest spot.
    private static func castWeight(_ episodes: Int?) -> Double {
        max(guestFloor, min(1, Double(episodes ?? 0) / regularRunEpisodes))
    }

    private static let topBilled = 5
    private static let billingFalloff = 3.0
    private static let crewWeight = 0.6
    private static let regularRunEpisodes = 12.0
    private static let guestFloor = 0.05
    private static let recencyBonus = 0.35
    private static let recentMonths = 24
}

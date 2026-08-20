//
//  Person+KnownFor.swift
//  MovieTracker
//
//  Ranks a person's credits by what they are known for.
//

import Foundation

extension Person {
    // Votes alone read as noise, so a title's notability is discounted by how small the part was.
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

    // Log-scaled so a 20x vote gap can't swamp the role weighting, then nudged for recent work.
    private static func score(votes: Int?, weight: Double, isRecent: Bool) -> Double {
        log10(Double(votes ?? 0) + 10) * weight + (isRecent ? recencyBonus : 0)
    }

    // The top-billed few share full weight: the gap between 1st and 4th billing isn't meaningful.
    private static func billingWeight(_ order: Int?) -> Double {
        guard let order else { return crewWeight }
        guard order > topBilled else { return 1 }
        return 1 / (1 + Double(order - topBilled) / billingFalloff)
    }

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

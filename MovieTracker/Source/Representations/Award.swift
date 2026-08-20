//
//  Award.swift
//  MovieTracker
//

import Foundation

/// One award category a title won or was nominated for. TMDB has none, so these come from Wikidata.
struct Award: Identifiable, Hashable, Sendable {
    var category: String
    var series: String?
    var year: Int?
    var isWin: Bool

    var id: String { "\(series ?? "")|\(category)|\(year.map(String.init) ?? "")" }

    // Wikidata prefixes a category with its series, which the section header already carries.
    var shortCategory: String {
        guard let separator = category.range(of: " for ") else { return category }
        return String(category[separator.upperBound...])
    }

    var yearString: String { year.map(String.init) ?? "" }
}

/// The awards a title took from one body ("Academy Awards"), wins before nominations.
struct AwardSeries: Identifiable, Hashable, Sendable {
    var name: String
    var awards: [Award]

    var id: String { name }
    var wins: Int { awards.count { $0.isWin } }
    var nominations: Int { awards.count - wins }
}

struct AwardsDigest: Equatable, Sendable {
    var series: [AwardSeries] = []

    var isEmpty: Bool { series.isEmpty }
    var wins: Int { series.reduce(0) { $0 + $1.wins } }
    var nominations: Int { series.reduce(0) { $0 + $1.nominations } }

    var summary: String? {
        guard !isEmpty else { return nil }
        let parts = [
            wins > 0 ? "\(wins) \(wins == 1 ? "Win" : "Wins")" : nil,
            nominations > 0 ? "\(nominations) \(nominations == 1 ? "Nom" : "Noms")" : nil,
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " &\n")
    }
}

// MARK: - Assembly

extension AwardsDigest {
    static let ungrouped = "Other Awards"

    // Wikidata records a win as both "award received" and "nominated for", so the same category arrives twice.
    init(awards: [Award]) {
        var best: [String: Award] = [:]
        for award in awards {
            let key = "\(award.series ?? "")|\(award.category)|\(award.yearString)"
            if let existing = best[key], existing.isWin || !award.isWin { continue }
            best[key] = award
        }

        let grouped = Dictionary(grouping: best.values) { $0.series ?? Self.ungrouped }
        series = grouped
            .map { name, awards in
                AwardSeries(name: name, awards: awards.sorted(by: Self.rowOrder))
            }
            // Busiest series first, so the Oscars lead a film and the Emmys a show without naming either.
            .sorted { left, right in
                if left.awards.count != right.awards.count {
                    return left.awards.count > right.awards.count
                }
                return left.name < right.name
            }
    }

    private static func rowOrder(_ left: Award, _ right: Award) -> Bool {
        if left.year != right.year { return (left.year ?? 0) > (right.year ?? 0) }
        if left.isWin != right.isWin { return left.isWin }
        return left.shortCategory < right.shortCategory
    }
}

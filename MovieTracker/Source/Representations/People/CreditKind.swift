//
//  CreditKind.swift
//  MovieTracker
//

import Foundation

/// What a person did on a title, from TMDB's cast/crew split and the crew department.
enum CreditKind: String, Codable, CaseIterable, Identifiable, Sendable {
    // Declaration order ranks a person's several roles on one title, and acting leads.
    case acting, directing, writing, producing, crew, appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .acting: return "Acting"
        case .directing: return "Directing"
        case .writing: return "Writing"
        case .producing: return "Producing"
        case .crew: return "Other Crew"
        case .appearance: return "Self & Thanks"
        }
    }

    var rank: Int { Self.allCases.firstIndex(of: self) ?? Self.allCases.count }

    static func resolve(isCast: Bool, role: String?, department: String?) -> CreditKind {
        if isExtraneous(role) { return .appearance }
        guard !isCast else { return .acting }
        switch department {
        case "Directing": return .directing
        case "Writing": return .writing
        case "Production": return .producing
        default: return .crew
        }
    }

    // TMDB files attribution-only jobs such as "Idea" under Writing beside real screenplays.
    static func isExtraneous(_ role: String?) -> Bool {
        guard let role = role?.lowercased() else { return false }
        if role.contains("thanks") || role == "idea" { return true }
        // Hand-entered, so "Self" gets a character of slack for typos. First word only and no longer:
        // "Herself" and "Selfish Man" are parts someone played.
        let firstWord = role.prefix { !" -–/,(".contains($0) }
        return firstWord.hasPrefix("self") && firstWord.count <= "self".count + 1
    }

    static func present(in credits: [MediaRef]) -> [CreditKind] {
        allCases.filter { kind in credits.contains { $0.creditKinds.contains(kind) } }
    }

    static func merge(_ credits: [(kind: CreditKind, role: String?, isCast: Bool)])
        -> (kind: CreditKind, kinds: Set<CreditKind>, character: String?, jobs: [String]) {
        let ordered = credits.enumerated()
            .sorted { ($0.element.kind.rank, $0.offset) < ($1.element.kind.rank, $1.offset) }
            .map(\.element)
        var seen = Set<String>()
        let distinct = ordered.filter { credit in
            guard let role = credit.role, !role.isEmpty else { return false }
            return seen.insert(role).inserted
        }
        let characters = distinct.filter(\.isCast).compactMap(\.role)
        // TMDB repeats a title with an empty character; that row reads as acting and would outrank "Self".
        let named = distinct.isEmpty ? ordered : distinct
        return (named.first?.kind ?? .crew,
                Set(named.map(\.kind)),
                characters.isEmpty ? nil : characters.joined(separator: ", "),
                distinct.filter { !$0.isCast }.compactMap(\.role))
    }
}

/// Crew job titles as a credit row shows them.
enum CreditJob {
    // Matched as substrings, so a compound title keeps the rest of itself. Longest first: several overlap.
    private static let abbreviations = [
        ("Director of Photography", "DP"),
        ("Original Music Composer", "Composer"),
        ("Associate Producer", "Assoc. Producer"),
        ("Executive Producer", "EP"),
    ]

    static func short(_ job: String) -> String {
        for (long, short) in abbreviations where job.contains(long) {
            return job.replacingOccurrences(of: long, with: short)
        }
        return job
    }

    static func line(_ jobs: [String]?) -> String? {
        guard let jobs, !jobs.isEmpty else { return nil }
        return jobs.map(short).joined(separator: ", ")
    }
}

//
//  CreditKind.swift
//  MovieTracker
//

import Foundation

/// What a person did on a title, from TMDB's cast/crew split and the crew department.
/// Ranks their duplicate credits, and gives the filmography something to filter by.
enum CreditKind: String, Codable, CaseIterable, Identifiable, Sendable {
    // Declaration order is the ranking order: a person credited twice on one title is listed
    // once, under whichever of their roles comes first here.
    case directing, acting, writing, producing, crew, appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .directing: return "Directing"
        case .acting: return "Acting"
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

    /// Courtesy credits rather than work on the title: appearing as yourself, a thanks, or an
    /// attribution-only job ("Idea", which TMDB files under Writing beside real screenplays).
    static func isExtraneous(_ role: String?) -> Bool {
        guard let role = role?.lowercased() else { return false }
        if role.contains("thanks") || role == "idea" { return true }
        // Hand-entered, so "Self" gets a character of slack for typos ("Selft"). First word
        // only, and no longer: "Herself" and "Selfish Man" are parts someone played.
        let firstWord = role.prefix { !" -–/,(".contains($0) }
        return firstWord.hasPrefix("self") && firstWord.count <= "self".count + 1
    }

    /// The kinds these credits actually cover, in ranking order — what a filter can offer.
    static func present(in credits: [MediaRef]) -> [CreditKind] {
        allCases.filter { kind in credits.contains { $0.creditKind == kind } }
    }

    /// Several jobs on one title as the single credit a row shows: every distinct role, most
    /// prominent first ("Director, Writer, Producer"), filed under the top-ranking kind.
    static func merge(_ credits: [(kind: CreditKind, role: String?)]) -> (kind: CreditKind, role: String?) {
        let ordered = credits.enumerated()
            .sorted { ($0.element.kind.rank, $0.offset) < ($1.element.kind.rank, $1.offset) }
        var seen = Set<String>()
        let roles = ordered
            .compactMap { $0.element.role }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        return (ordered.first?.element.kind ?? .crew,
                roles.isEmpty ? nil : roles.joined(separator: ", "))
    }
}

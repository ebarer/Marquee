//
//  CreditKind.swift
//  MovieTracker
//

import Foundation

/// What a person did on a title, from TMDB's cast/crew split and the crew department.
enum CreditKind: String, Codable, CaseIterable, Identifiable, Sendable {
    /// One of a person's credits on a single title. `episodes` is 0 for a film.
    typealias Entry = (kind: CreditKind, role: String?, isCast: Bool, episodes: Int)

    // Declaration order is the order the filter menu offers them in.
    case acting, hosting, directing, writing, producing, crew, appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .acting: return "Acting"
        case .hosting: return "Hosting"
        case .directing: return "Directing"
        case .writing: return "Writing"
        case .producing: return "Producing"
        case .crew: return "Other Crew"
        case .appearance: return "Self & Thanks"
        }
    }

    // Ranks a person's several roles on one title. Hosting leads: running the show is what the
    // title was for them, ahead of a sketch part they also took that night.
    private static let ranked: [CreditKind] = [.hosting, .acting, .directing, .writing,
                                               .producing, .crew, .appearance]

    var rank: Int { Self.ranked.firstIndex(of: self) ?? Self.ranked.count }

    static func resolve(isCast: Bool, role: String?, department: String?,
                        format: CreditFormat = .scripted) -> CreditKind {
        // The function after "Self" is the job, and it outranks the appearance the word would make
        // it: running the show is hosting, and playing the sketches is a performance.
        if isHosting(role) { return .hosting }
        if isPerforming(role) { return .acting }
        if isExtraneous(role) { return .appearance }
        // A talk show has no parts, so a cast credit there is an appearance whatever TMDB filed as
        // the character — it hands one guest's name to another often enough to matter.
        if isCast, format == .talk { return .appearance }
        // Sketch comedy files under news, and those characters are the cast's real body of work,
        // so there only a credit naming nobody is an appearance.
        if isCast, format == .unscripted, role?.isEmpty ?? true { return .appearance }
        guard !isCast else { return .acting }
        switch department {
        case "Directing": return .directing
        case "Writing": return .writing
        case "Production": return .producing
        default: return .crew
        }
    }

    // Running the show, as TMDB writes it: the function after "Self", or the bare job on an
    // awards night. Presenting, narrating or turning up to play a song is not hosting.
    private static let hostingFunctions: Set<String> = ["host", "guest host", "co-host", "cohost"]

    // TMDB prefixes a repertory player with "Self - Various Characters", but sketch work is a
    // performance and the body of work a cast member is known for.
    private static let performingFunctions: Set<String> = [
        "various", "various characters", "various roles", "cast", "performer",
        "repertory player", "player",
    ]

    static func isHosting(_ role: String?) -> Bool {
        hostingFunctions.contains(function(of: role))
    }

    static func isPerforming(_ role: String?) -> Bool {
        performingFunctions.contains(function(of: role))
    }

    private static func function(of role: String?) -> String {
        guard let role else { return "" }
        return selfFunction(role).lowercased().trimmingCharacters(in: .whitespaces)
    }

    // Every way TMDB writes someone appearing as themselves.
    private static let selfWords: Set<String> = ["self", "himself", "herself", "themselves",
                                                 "themself", "itself", "oneself"]

    // Whole word only, since "Selfish Man" is a part someone played. Hand-entered, so a bare
    // "Self" keeps a character of slack for the "Selft" typo.
    static func isSelfWord(_ word: String) -> Bool {
        if selfWords.contains(word) { return true }
        return word.hasPrefix("self") && word.count <= "self".count + 1
    }

    // TMDB files attribution-only jobs such as "Idea" under Writing beside real screenplays.
    static func isExtraneous(_ role: String?) -> Bool {
        guard let role = role?.lowercased() else { return false }
        if role.contains("thanks") || role == "idea" { return true }
        return isSelfWord(String(role.prefix { !" -–/,(".contains($0) }))
    }

    static func present(in credits: [MediaRef]) -> [CreditKind] {
        allCases.filter { kind in credits.contains { $0.creditKinds.contains(kind) } }
    }

    static func merge(_ credits: [Entry], unscripted: Bool = false)
        -> (kind: CreditKind, kinds: Set<CreditKind>, character: String?, jobs: [String]) {
        let ordered = credits.enumerated()
            .sorted { ($0.element.kind.rank, $0.offset) < ($1.element.kind.rank, $1.offset) }
            .map(\.element)
        var seen = Set<String>()
        let distinct = ordered.filter { credit in
            guard let role = credit.role, !role.isEmpty else { return false }
            return seen.insert(role).inserted
        }
        let lead = leading(of: distinct.filter(\.isCast))
        var characters = billed(spoken(by: lead, unscripted: unscripted))
        // A talk show that named no character at all is still describing a guest spot.
        if characters.isEmpty, unscripted, ordered.contains(where: \.isCast) {
            characters = [guestRole]
        }
        // Only the credit that speaks for the title carries a cast kind, or a one-episode sketch
        // part would hold a hosting job on screen after hosting is hidden. Crew work is its own job.
        var kinds = Set(distinct.filter { !$0.isCast }.map(\.kind) + lead.map(\.kind))
        // TMDB repeats a title with an empty character; that row reads as acting and would outrank "Self".
        if kinds.isEmpty { kinds = Set(ordered.map(\.kind)) }
        return (kinds.min(by: { $0.rank < $1.rank }) ?? .crew,
                kinds,
                characters.isEmpty ? nil : characters.joined(separator: ", "),
                distinct.filter { !$0.isCast }.compactMap(\.role))
    }

    private static let guestRole = "Guest"

    // The biggest body of work on the title speaks for it: eleven seasons in the repertory outrank
    // the one night the same person came back to host.
    private static func leading(of cast: [Entry]) -> [Entry] {
        let ranked = cast.sorted { ($0.episodes, $1.kind.rank) > ($1.episodes, $0.kind.rank) }
        guard let best = ranked.first?.kind else { return [] }
        return ranked.filter { $0.kind == best }
    }

    private static func spoken(by lead: [Entry], unscripted: Bool) -> [String] {
        guard lead.first?.kind == .appearance else { return lead.compactMap(\.role) }
        // Only the rows that say "Self" are about this person: TMDB files another guest's name as
        // the character often enough to matter.
        let selves = lead.filter { isExtraneous($0.role) }
        let roles = (selves.isEmpty ? lead : selves).compactMap(\.role)
        // TMDB writes a guest spot as a bare "Self" or "Himself" on some shows, "Self - Guest" on
        // others.
        return unscripted ? roles.map { isSelfWord($0.lowercased()) ? guestRole : $0 } : roles
    }

    // A variety show lists every drop-in a person made beside the one they were billed for, so the
    // credited role speaks for the title and the uncredited ones only stand in when it is alone.
    private static func billed(_ roles: [String]) -> [String] {
        let credited = roles.filter { !$0.lowercased().contains("(uncredited)") }
        let named = (credited.isEmpty ? roles : credited).map(presented)
        // A bare "Self" says nothing beside a row naming what they did there.
        let described = named.filter { !isSelfWord($0.lowercased()) }
        // Two rows can say the same thing once the function is promoted out of them.
        var seen = Set<String>()
        return (described.isEmpty ? named : described).filter { seen.insert($0).inserted }
    }

    private static let castRole = "Cast"

    // TMDB writes a repertory player as "Various", "Various Characters" or "Self - Various", so the
    // row would name the same job three ways.
    private static func presented(_ role: String) -> String {
        isPerforming(role) ? castRole : selfFunction(role)
    }

    // "Self - Host" names what they did there; the "Self" says nothing the row doesn't already.
    private static func selfFunction(_ role: String) -> String {
        let lowered = role.lowercased()
        for word in selfWords where lowered.hasPrefix(word + " - ") {
            let function = String(role.dropFirst(word.count + 3))
            return function.isEmpty ? role : function
        }
        return role
    }
}

/// How much of a show is written, from TMDB's genre ids, since that decides whether a cast credit
/// can name a part at all.
enum CreditFormat {
    case scripted, unscripted, talk

    var isUnscripted: Bool { self != .scripted }

    private static let talkGenreID = 10767
    // Not talk: TMDB tags Saturday Night Live as news, and its sketches are parts people played.
    private static let unscriptedGenreIDs: Set<Int> = [10763, 10764]

    init(genreIDs: [Int]?) {
        guard let genreIDs else { self = .scripted; return }
        if genreIDs.contains(Self.talkGenreID) {
            self = .talk
        } else if genreIDs.contains(where: Self.unscriptedGenreIDs.contains) {
            self = .unscripted
        } else {
            self = .scripted
        }
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

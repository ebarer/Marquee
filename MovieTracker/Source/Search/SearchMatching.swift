//
//  SearchMatching.swift
//  MovieTracker
//
//  Pure, network-free matching and ranking used by `SearchModel`.
//

import Foundation

enum SearchMatching {
    static func normalized(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func heroSegments(of role: String) -> [String] {
        role.split(separator: "/").map { segment in
            var name = segment.lowercased()
            while let open = name.firstIndex(of: "("), let close = name[open...].firstIndex(of: ")") {
                name.removeSubrange(open...close)
            }
            name = name.trimmingCharacters(in: .whitespaces)
            if name.hasPrefix("the ") { name = String(name.dropFirst(4)) }
            return normalized(name)
        }
    }

    // TMDB matches interpunct titles only literally, so a spaced or hyphenated spelling needs this.
    static func interpunctVariant(of query: String) -> String? {
        guard !query.contains("·"), query.contains(" ") || query.contains("-") else { return nil }
        var out = ""
        var lastWasSeparator = false
        for ch in query {
            if ch == " " || ch == "-" {
                if !lastWasSeparator { out.append("·") }
                lastWasSeparator = true
            } else {
                out.append(ch)
                lastWasSeparator = false
            }
        }
        return out
    }

    // Recovers a film that TMDB's erratic incremental search drops mid-type.
    static func shouldTryAnchorRecovery(query: String, lastStrongQuery anchor: String,
                                        minLength: Int) -> Bool {
        guard !anchor.isEmpty, query != anchor, query.count >= minLength else { return false }
        return query.hasPrefix(anchor) || anchor.hasPrefix(query)
    }

    // Works around TMDB's space-sensitive title search ("ironman" to "iron man").
    static func spacedVariant(of query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.contains(" ") else { return nil }
        // Longer suffixes first, since "woman" also ends in "man".
        let suffixes = ["woman", "women", "man", "men", "girl", "boy"]
        for suffix in suffixes where trimmed.hasSuffix(suffix) && trimmed.count > suffix.count + 2 {
            return String(trimmed.dropLast(suffix.count)) + " " + suffix
        }
        return nil
    }

    // Queries must be stripped the same way so both sides agree.
    static func articleStripped(_ text: String) -> String {
        let lowered = text.lowercased()
        for article in ["the ", "an ", "a "] where lowered.hasPrefix(article) {
            return String(lowered.dropFirst(article.count))
        }
        return lowered
    }

    static func titleMatches(_ title: String, normalizedQuery needle: String) -> Bool {
        normalized(articleStripped(title)) == needle
    }

    static func topFilmLeadsApply(topTitle: String, normalizedQuery needle: String,
                                  minQueryLength: Int) -> Bool {
        if titleMatches(topTitle, normalizedQuery: needle) { return true }
        guard needle.count >= minQueryLength else { return false }
        return normalized(articleStripped(topTitle)).hasPrefix(needle)
    }

    // Each stage only adds; none of them excludes the others.
    static func moviePeople(query: String,
                            films: [(movie: Movie, cast: [Person])],
                            minQueryLength: Int,
                            leadPrefixMinLength: Int,
                            topBilledPerFilm: Int,
                            minCharacterMatchVotes: Int,
                            leadFallbackCount: Int,
                            leadFallbackMinPopularity: Double) -> [Person] {
        let needle = normalized(articleStripped(query))
        guard !films.isEmpty else { return [] }

        var people: [Person] = []
        var seen = Set<Int>()
        func add(_ candidates: [Person]) {
            for person in candidates where seen.insert(person.id).inserted { people.append(person) }
        }

        // A query naming a character is answered by the people who played them, most notable film first.
        if needle.count >= minQueryLength {
            add(characterMatches(films, needle: needle, topBilledPerFilm: topBilledPerFilm,
                                 minVotes: minCharacterMatchVotes))
        }

        for group in filmLeads(query: query, films: films,
                               leadPrefixMinLength: leadPrefixMinLength,
                               topBilledPerFilm: topBilledPerFilm,
                               leadFallbackMinPopularity: leadFallbackMinPopularity) {
            add(group.people)
        }
        return people
    }

    static func filmLeads(query: String,
                          films: [(movie: Movie, cast: [Person])],
                          leadPrefixMinLength: Int,
                          topBilledPerFilm: Int,
                          leadFallbackMinPopularity: Double) -> [(filmID: Int, people: [Person])] {
        let needle = normalized(articleStripped(query))
        return films.compactMap { movie, cast in
            guard (movie.popularity ?? 0) >= leadFallbackMinPopularity,
                  topFilmLeadsApply(topTitle: movie.title, normalizedQuery: needle,
                                    minQueryLength: leadPrefixMinLength) else { return nil }
            return (movie.id, Array(cast.prefix(topBilledPerFilm)))
        }
    }

    // Ranked on vote count rather than volatile popularity; the floor skips films that merely name a character.
    static func characterMatches(_ films: [(movie: Movie, cast: [Person])],
                                 needle: String, topBilledPerFilm: Int,
                                 minVotes: Int) -> [Person] {
        var order: [Int] = []
        var byPerson: [Int: (person: Person, notability: Int)] = [:]
        for (movie, cast) in films {
            let notability = movie.voteCount ?? 0
            guard notability >= minVotes else { continue }
            for person in cast.prefix(topBilledPerFilm) {
                guard let role = person.role,
                      heroSegments(of: role).contains(needle) else { continue }
                if let existing = byPerson[person.id] {
                    if notability > existing.notability {
                        byPerson[person.id] = (existing.person, notability)
                    }
                } else {
                    byPerson[person.id] = (person, notability)
                    order.append(person.id)
                }
            }
        }
        return order
            .map { byPerson[$0]! }
            .sorted { $0.notability > $1.notability }
            .map(\.person)
    }

    // Lower is stronger: 0 exact, 1 title prefix, 2 word prefix, 3 contains, 4 none.
    static func titleRelevance(_ title: String, normalizedQuery needle: String) -> Int {
        guard !needle.isEmpty else { return 1 }
        let full = normalized(articleStripped(title))
        if full == needle { return 0 }
        if full.hasPrefix(needle) { return 1 }
        let wordStart = articleStripped(title).lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .contains { normalized(String($0)).hasPrefix(needle) }
        if wordStart { return 2 }
        if full.contains(needle) { return 3 }
        return 4
    }

    // Any exact title match is kept, so a directly-searched foreign show ("Squid Game") still appears.
    static func relevantShows(_ shows: [Show], normalizedQuery needle: String,
                              voteFloor: Int, popularityFloor: Double) -> [Show] {
        shows.filter { show in
            if titleMatches(show.name, normalizedQuery: needle) { return true }
            guard show.originCountry?.contains("US") ?? false else { return false }
            return (show.voteCount ?? 0) >= voteFloor || (show.popularity ?? 0) >= popularityFloor
        }
    }

    // Votes decide in/out, being a floor junk can't spike past; popularity decides order.
    static func rankedForDisplay(_ movies: [Movie], minVotes: Int) -> [Movie] {
        func byPopularity(_ lhs: Movie, _ rhs: Movie) -> Bool {
            (lhs.popularity ?? 0) > (rhs.popularity ?? 0)
        }
        let notable = movies.filter { ($0.voteCount ?? 0) >= minVotes }.sorted(by: byPopularity)
        let noise = movies.filter { ($0.voteCount ?? 0) < minVotes }.sorted(by: byPopularity)
        return notable + noise
    }

    static func featuredPeople(castMatched: [Person], named: [Person], cap: Int,
                               namedNoiseFloor: Float = 0, query: String = "",
                               titleOwnsQuery: Bool = false) -> [Person] {
        let credibleNamed = named.filter {
            $0.popularity >= namedNoiseFloor || $0.profilePicture != nil
        }
        let byPopularity = credibleNamed.sorted { $0.popularity > $1.popularity }
        // A title that is the query holds it against a lone namesake ("dune"), but not against a name
        // several notable people share.
        let needle = normalized(articleStripped(query))
        let namesakes = byPopularity.filter {
            $0.popularity >= namedNoiseFloor && nameMatches($0.name, normalizedQuery: needle)
        }
        let nameMatched = (namesakes.count > 1 || !titleOwnsQuery) ? namesakes : []

        var seen = Set<Int>()
        var merged: [Person] = []
        for person in nameMatched + castMatched + byPopularity
        where seen.insert(person.id).inserted {
            merged.append(person)
        }
        return Array(merged.prefix(cap))
    }

    // Whole segments only: "office" must not claim someone called "Officer".
    static func nameMatches(_ name: String, normalizedQuery needle: String) -> Bool {
        guard needle.count >= 3 else { return false }
        return name.split(whereSeparator: { $0 == " " || $0 == "-" })
            .contains { normalized(String($0)) == needle }
    }

    static func inlinePeopleCount(_ featured: [Person], castMatchedIDs: Set<Int>,
                                  inlinePopularityFloor: Float, minInline: Int,
                                  previewLimit: Int) -> Int {
        var prominent = 0
        for person in featured {
            let isCastMatch = castMatchedIDs.contains(person.id)
            let isProminentNamed = person.popularity >= inlinePopularityFloor
                && person.profilePicture != nil
            guard isCastMatch || isProminentNamed else { break }
            prominent += 1
        }
        let inline = prominent > 0 ? prominent : minInline
        return min(inline, previewLimit, featured.count)
    }

    // Clearing one relevance step costs this factor, so relevance can't bury a phenomenon.
    private static let relevanceDiscount = 8.0

    static func matchWeight(relevance: Int) -> Double {
        pow(relevanceDiscount, -Double(max(0, relevance - 1)))
    }

    // Votes scaled by how much of a phenomenon the title is today, so a back catalogue can't bury a current hit.
    static func notability(_ ref: MediaRef, popularityBenchmark benchmark: Double) -> Double {
        let trending = benchmark > 0 ? ref.popularity / benchmark : 0
        return Double(ref.voteCount) * (1 + trending)
    }

    static func interlaced(movies: [Movie], shows: [Show], query: String = "",
                           voteFloor: Int = 0, relatedMovies: [Int: Int] = [:],
                           now: Date = .now,
                           popularityBenchmark: Double = .infinity) -> [MediaRef] {
        let needle = normalized(articleStripped(query))
        let refs = movies.map(MediaRef.movie) + shows.map(MediaRef.show)

        // A sibling is as relevant as the match that pulled it in, never on a stronger footing than its seed.
        func relevance(_ ref: MediaRef) -> Int {
            let literal = titleRelevance(ref.title, normalizedQuery: needle)
            guard case .movie(let movie) = ref, let seeded = relatedMovies[movie.id] else {
                return literal
            }
            return min(seeded, literal)
        }
        func score(_ ref: MediaRef) -> Double {
            notability(ref, popularityBenchmark: popularityBenchmark)
                * matchWeight(relevance: relevance(ref))
        }

        let tiers = Dictionary(grouping: refs, by: relevance)
        let leaders = currentReleaseLeaders(tiers, voteFloor: voteFloor,
                                            popularityFloor: popularityBenchmark, now: now)
        // A leader tops its own tier: too new to have the votes, but what the query means now.
        let ceilings = tiers.mapValues { group in group.map(score).max() ?? 0 }
        func ranked(_ ref: MediaRef) -> Double {
            guard leaders.contains(ref.id) else { return score(ref) }
            return (ceilings[relevance(ref)] ?? 0) + 1
        }

        return refs.enumerated()
            .sorted { lhs, rhs in
                let (left, right) = (ranked(lhs.element), ranked(rhs.element))
                if left != right { return left > right }
                if lhs.element.popularity != rhs.element.popularity {
                    return lhs.element.popularity > rhs.element.popularity
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    // The vote floor stops a sequel displacing its classic.
    private static func currentReleaseLeaders(_ tiers: [Int: [MediaRef]], voteFloor: Int,
                                              popularityFloor: Double,
                                              now: Date) -> Set<String> {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -inReleaseDays, to: now)
        else { return [] }

        var leaders = Set<String>()
        for group in tiers.values {
            guard let top = group.max(by: { $0.popularity < $1.popularity }),
                  top.popularity >= popularityFloor, top.voteCount >= voteFloor,
                  let date = top.date, date >= cutoff else { continue }
            leaders.insert(top.id)
        }
        return leaders
    }

    // Roughly a theatrical run: how long a title still counts as the current release.
    private static let inReleaseDays = 90
}

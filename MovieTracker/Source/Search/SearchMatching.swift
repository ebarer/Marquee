//
//  SearchMatching.swift
//  MovieTracker
//
//  Pure, network-free matching/ranking used by SearchModel.
//

import Foundation

enum SearchMatching {
    /// Lowercased, alphanumerics only — so "Spider-Man" matches "spiderman".
    static func normalized(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Hero-name variants of a role — each "/"-segment, minus parentheticals and a leading
    /// "The" — so a title-role credit reduces to a name a query can match exactly.
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

    /// Query with space/hyphen runs replaced by "·", so separator spellings match interpunct
    /// titles TMDB matches only literally. Nil when there's nothing to convert.
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

    /// Whether `query` extends or prefixes a previously-strong anchor enough to re-run it,
    /// recovering a film that TMDB's erratic incremental search drops mid-type.
    static func shouldTryAnchorRecovery(query: String, lastStrongQuery anchor: String,
                                        minLength: Int) -> Bool {
        guard !anchor.isEmpty, query != anchor, query.count >= minLength else { return false }
        return query.hasPrefix(anchor) || anchor.hasPrefix(query)
    }

    /// A single-token query split before a trailing hero suffix ("ironman" → "iron man"),
    /// working around TMDB's space-sensitive title search. Nil when there's no such split.
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

    /// Lowercased text with a leading article removed. Queries must be stripped the same
    /// way so both sides agree (see `moviePeople`).
    static func articleStripped(_ text: String) -> String {
        let lowered = text.lowercased()
        for article in ["the ", "an ", "a "] where lowered.hasPrefix(article) {
            return String(lowered.dropFirst(article.count))
        }
        return lowered
    }

    /// Whether a title, article-stripped and normalized, exactly equals the (likewise
    /// stripped) query — confirms the query names this film before surfacing its leads.
    static func titleMatches(_ title: String, normalizedQuery needle: String) -> Bool {
        normalized(articleStripped(title)) == needle
    }

    /// Whether the top film's leads stand in for a character match: the query exactly names
    /// the film, or is a ≥ `minQueryLength` prefix of its title (the floor avoids churn).
    static func topFilmLeadsApply(topTitle: String, normalizedQuery needle: String,
                                  minQueryLength: Int) -> Bool {
        if titleMatches(topTitle, normalizedQuery: needle) { return true }
        guard needle.count >= minQueryLength else { return false }
        return normalized(articleStripped(topTitle)).hasPrefix(needle)
    }

    /// People from the top movie hits: cast credited as the searched character (ranked by
    /// their film's vote count, not volatile `popularity`), else the named film's leads.
    static func moviePeople(query: String,
                            films: [(movie: Movie, cast: [Person])],
                            minQueryLength: Int,
                            leadPrefixMinLength: Int,
                            topBilledPerFilm: Int,
                            minCharacterMatchVotes: Int,
                            leadFallbackCount: Int,
                            leadFallbackMinPopularity: Double) -> [Person] {
        // Article-strip so query and titles agree.
        let needle = normalized(articleStripped(query))
        guard !films.isEmpty else { return [] }

        // 1) Cast credited as the searched character. The vote floor skips obscure films
        //    that merely name one after the query; the length gate stops generic words.
        if needle.count >= minQueryLength {
            var order: [Int] = []
            var byPerson: [Int: (person: Person, notability: Int)] = [:]
            for (movie, cast) in films {
                let filmNotability = movie.voteCount ?? 0
                guard filmNotability >= minCharacterMatchVotes else { continue }
                for person in cast.prefix(topBilledPerFilm) {
                    guard let role = person.role,
                          heroSegments(of: role).contains(needle) else { continue }
                    if let existing = byPerson[person.id] {
                        if filmNotability > existing.notability {
                            byPerson[person.id] = (existing.person, filmNotability)
                        }
                    } else {
                        byPerson[person.id] = (person, filmNotability)
                        order.append(person.id)
                    }
                }
            }
            if !order.isEmpty {
                return order
                    .map { byPerson[$0]! }
                    .sorted { $0.notability > $1.notability }
                    .map(\.person)
            }
        }

        // 2) Fallback: the top film's leads when the query names it but no character
        //    matched (the lead is credited by real name, not the hero alias).
        guard let top = films.first,
              (top.movie.popularity ?? 0) >= leadFallbackMinPopularity,
              topFilmLeadsApply(topTitle: top.movie.title, normalizedQuery: needle,
                                minQueryLength: leadPrefixMinLength) else {
            return []
        }
        return Array(top.cast.prefix(leadFallbackCount))
    }

    /// How well a title matches, lower = stronger: 0 exact, 1 title prefix, 2 word prefix,
    /// 3 contains, 4 none. Both sides are article-stripped so "The Office"/"office" agree.
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

    /// Trims TV noise: keeps US-aired shows that are established or trending, plus any exact
    /// title match — so a directly-searched foreign show ("Squid Game") still appears.
    static func relevantShows(_ shows: [Show], normalizedQuery needle: String,
                              voteFloor: Int, popularityFloor: Double) -> [Show] {
        shows.filter { show in
            if titleMatches(show.name, normalizedQuery: needle) { return true }
            guard show.originCountry?.contains("US") ?? false else { return false }
            return (show.voteCount ?? 0) >= voteFloor || (show.popularity ?? 0) >= popularityFloor
        }
    }

    /// Votes decide IN/OUT (a stable floor junk can't spike past), popularity decides ORDER
    /// (trending beats older-but-voted); the low-vote tail sinks below.
    static func rankedForDisplay(_ movies: [Movie], minVotes: Int) -> [Movie] {
        func byPopularity(_ lhs: Movie, _ rhs: Movie) -> Bool {
            (lhs.popularity ?? 0) > (rhs.popularity ?? 0)
        }
        let notable = movies.filter { ($0.voteCount ?? 0) >= minVotes }.sorted(by: byPopularity)
        let noise = movies.filter { ($0.voteCount ?? 0) < minVotes }.sorted(by: byPopularity)
        return notable + noise
    }

    /// Cast matches first (from films and the top show), then name matches by popularity, deduped
    /// and capped. A name match with neither a photo nor `namedNoiseFloor` popularity is dropped.
    static func featuredPeople(castMatched: [Person], named: [Person], cap: Int,
                               namedNoiseFloor: Float = 0) -> [Person] {
        let credibleNamed = named.filter {
            $0.popularity >= namedNoiseFloor || $0.profilePicture != nil
        }

        var seen = Set<Int>()
        var merged: [Person] = []
        for person in castMatched where seen.insert(person.id).inserted {
            merged.append(person)
        }
        for person in credibleNamed.sorted(by: { $0.popularity > $1.popularity })
        where seen.insert(person.id).inserted {
            merged.append(person)
        }
        return Array(merged.prefix(cap))
    }

    /// Length of `featured`'s inline "prominent" prefix — cast matches, plus named people
    /// clearing `inlinePopularityFloor` *and* having a photo. Falls back to `minInline`.
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

    /// What a weaker title match costs in notability: clearing one relevance step takes this
    /// factor, so relevance decides between peers but can't bury a phenomenon.
    private static let relevanceDiscount = 8.0

    static func matchWeight(relevance: Int) -> Double {
        pow(relevanceDiscount, -Double(max(0, relevance - 1)))
    }

    /// Accumulated attention (`voteCount`) scaled by how much of a phenomenon the title is
    /// today, so a current hit isn't buried by a back catalogue's years of votes.
    static func notability(_ ref: MediaRef, popularityBenchmark benchmark: Double) -> Double {
        let trending = benchmark > 0 ? ref.popularity / benchmark : 0
        return Double(ref.voteCount) * (1 + trending)
    }

    /// Movies and shows in one ranked list, by notability discounted for a weaker title match
    /// — "House of the Dragon" for "dragon" beats an obscure film the query merely prefixes.
    static func interlaced(movies: [Movie], shows: [Show], query: String = "",
                           voteFloor: Int = 0, relatedMovies: [Int: Int] = [:],
                           now: Date = .now,
                           popularityBenchmark: Double = .infinity) -> [MediaRef] {
        let needle = normalized(articleStripped(query))
        let refs = movies.map(MediaRef.movie) + shows.map(MediaRef.show)

        // A sibling is as relevant as the match that pulled it in — never on a stronger
        // footing than its own seed.
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

    /// Per tier, the title in release now that leads it on popularity — what the query means
    /// today, before its votes accrue. The floor stops any sequel displacing its classic.
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

    /// Roughly a theatrical run — how long a title still counts as the current release.
    private static let inReleaseDays = 90
}

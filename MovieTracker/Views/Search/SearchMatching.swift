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

    /// Hero-name variants of a role: each "/"-segment, parentheticals and a leading
    /// "The" removed, normalized — so a title-role credit reduces to the hero name
    /// for an exact query match, while a descriptive bit-part doesn't.
    static func heroSegments(of role: String) -> [String] {
        role.split(separator: "/").map { segment in
            var s = segment.lowercased()
            while let open = s.firstIndex(of: "("), let close = s[open...].firstIndex(of: ")") {
                s.removeSubrange(open...close)
            }
            s = s.trimmingCharacters(in: .whitespaces)
            if s.hasPrefix("the ") { s = String(s.dropFirst(4)) }
            return normalized(s)
        }
    }

    /// Query with space/hyphen runs replaced by "·", so separator spellings match
    /// interpunct titles TMDB matches only literally. Nil when nothing to convert.
    /// Junk this pulls in for ordinary queries is low-vote and sinks in `rankedForDisplay`.
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

    /// Whether `query` relates to a previously-strong `lastStrongQuery` (extends or is
    /// a prefix of it, past the stem floor) enough to re-run that anchor — recovering a
    /// film TMDB's erratic incremental search drops mid-type. Caller confirms via `topFilmLeadsApply`.
    static func shouldTryAnchorRecovery(query: String, lastStrongQuery anchor: String,
                                        minLength: Int) -> Bool {
        guard !anchor.isEmpty, query != anchor, query.count >= minLength else { return false }
        return query.hasPrefix(anchor) || anchor.hasPrefix(query)
    }

    /// A spaced form of a single-token query split before a trailing hero suffix
    /// ("ironman" → "iron man", "antman" → "ant man"), or nil when there's no
    /// such split. Used to work around TMDB's space-sensitive title search.
    static func spacedVariant(of query: String) -> String? {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.contains(" ") else { return nil }
        // Longer suffixes first, since "woman" also ends in "man".
        let suffixes = ["woman", "women", "man", "men", "girl", "boy"]
        for suffix in suffixes where q.hasSuffix(suffix) && q.count > suffix.count + 2 {
            return String(q.dropLast(suffix.count)) + " " + suffix
        }
        return nil
    }

    /// Lowercased text with a leading article ("the "/"an "/"a ") removed. Callers
    /// pass it through `normalized`; queries must be stripped the same way so both
    /// sides agree (see `moviePeople`).
    static func articleStripped(_ text: String) -> String {
        let t = text.lowercased()
        for article in ["the ", "an ", "a "] where t.hasPrefix(article) {
            return String(t.dropFirst(article.count))
        }
        return t
    }

    /// Whether a movie title, article-stripped and normalized, is exactly the
    /// (already article-stripped + normalized) query — confirms the query names
    /// this film before surfacing its leads.
    static func titleMatches(_ title: String, normalizedQuery needle: String) -> Bool {
        normalized(articleStripped(title)) == needle
    }

    /// Whether the top film's leads should stand in for a character match: the query
    /// exactly names the film (any length) or is a ≥ `minQueryLength` prefix of its
    /// article-stripped title. The floor avoids churn; a prefix into a sequel is fine.
    static func topFilmLeadsApply(topTitle: String, normalizedQuery needle: String,
                                  minQueryLength: Int) -> Bool {
        if titleMatches(topTitle, normalizedQuery: needle) { return true }
        guard needle.count >= minQueryLength else { return false }
        return normalized(articleStripped(topTitle)).hasPrefix(needle)
    }

    /// People from the top movie hits: cast credited as the searched character
    /// (ranked by their film's vote count — enduring notability, not volatile
    /// `popularity`), else the lead(s) of the film the query names.
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

        // 1) Cast credited as the searched character, ranked by film vote count. The
        //    vote floor skips obscure films that merely name a character after the
        //    query; the length gate stops a short generic word matching every cast.
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

    /// How well a title matches the query, lower = stronger: 0 exact, 1 title starts with
    /// the query, 2 a word in the title starts with it, 3 contains it anywhere, 4 not at all.
    /// Both sides are article-stripped + normalized so "The Office"/"house" compare cleanly.
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

    /// Trims TV search noise: keeps US-aired shows that are established (`voteCount` ≥
    /// `voteFloor`) or trending (`popularity` ≥ `popularityFloor`), plus any exact title
    /// match — so a directly-searched foreign show (e.g. "Squid Game") still appears, while
    /// incidental foreign/low-signal junk ("Andro Melos", promo featurettes) drops out.
    static func relevantShows(_ shows: [Show], normalizedQuery needle: String,
                              voteFloor: Int, popularityFloor: Double) -> [Show] {
        shows.filter { show in
            if titleMatches(show.name, normalizedQuery: needle) { return true }
            guard show.originCountry?.contains("US") ?? false else { return false }
            return (show.voteCount ?? 0) >= voteFloor || (show.popularity ?? 0) >= popularityFloor
        }
    }

    /// Ranks for display: notable films (`voteCount` ≥ `minVotes`) first by current
    /// `popularity`, low-vote tail sunk below. Votes decide IN/OUT (a stable floor
    /// junk can't spike past), popularity decides ORDER (trending beats older-but-voted).
    static func rankedForDisplay(_ movies: [Movie], minVotes: Int) -> [Movie] {
        func byPopularity(_ a: Movie, _ b: Movie) -> Bool { (a.popularity ?? 0) > (b.popularity ?? 0) }
        let notable = movies.filter { ($0.voteCount ?? 0) >= minVotes }.sorted(by: byPopularity)
        let noise = movies.filter { ($0.voteCount ?? 0) < minVotes }.sorted(by: byPopularity)
        return notable + noise
    }

    /// People atop the results: movie matches first, then name matches by popularity,
    /// deduped and capped. Name matches with neither a photo nor ≥ `namedNoiseFloor`
    /// popularity are dropped as non-person entries; movie matches are never filtered.
    static func featuredPeople(movieMatched: [Person], named: [Person], cap: Int,
                               namedNoiseFloor: Float = 0) -> [Person] {
        let credibleNamed = named.filter {
            $0.popularity >= namedNoiseFloor || $0.profilePicture != nil
        }

        var seen = Set<Int>()
        var merged: [Person] = []
        for person in movieMatched where seen.insert(person.id).inserted {
            merged.append(person)
        }
        for person in credibleNamed.sorted(by: { $0.popularity > $1.popularity })
        where seen.insert(person.id).inserted {
            merged.append(person)
        }
        return Array(merged.prefix(cap))
    }

    /// Length of the inline "prominent" prefix of `featured` — movie matches, plus
    /// named people clearing `inlinePopularityFloor` AND with a photo (the photo
    /// folds low-confidence entries). Falls back to `minInline`, clamped to `previewLimit`.
    static func inlinePeopleCount(_ featured: [Person], movieMatchedIDs: Set<Int>,
                                  inlinePopularityFloor: Float, minInline: Int,
                                  previewLimit: Int) -> Int {
        var prominent = 0
        for person in featured {
            let isMovieMatch = movieMatchedIDs.contains(person.id)
            let isProminentNamed = person.popularity >= inlinePopularityFloor
                && person.profilePicture != nil
            guard isMovieMatch || isProminentNamed else { break }
            prominent += 1
        }
        let inline = prominent > 0 ? prominent : minInline
        return min(inline, previewLimit, featured.count)
    }
}

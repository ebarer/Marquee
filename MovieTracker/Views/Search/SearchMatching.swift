//
//  SearchMatching.swift
//  MovieTracker
//
//  Pure, network-free matching and ranking used by SearchModel. Isolated here so
//  the rules — character/title/spacing matching and notability ordering — can be
//  unit tested against synthetic data and adjusted if TMDB's shapes or behaviours
//  change, without touching the networking or view layers.
//

import Foundation

enum SearchMatching {
    /// Lowercased, alphanumerics only — so "Spider-Man" matches "spiderman".
    static func normalized(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// The character's "hero" name variants: each "/"-separated segment with any
    /// parenthetical aside and a leading "The" stripped, normalized to
    /// alphanumerics. So "Bruce Wayne / The Batman" and "Batman (Bruce Wayne)"
    /// both yield "batman" for an exact match against the query, while a bit-part
    /// like "Yeah Spider-Man Guy" never reduces to "spiderman".
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

    /// Whether a movie title, article-stripped and normalized, is exactly the
    /// (already normalized) query — confirms the query names this film before
    /// surfacing its leads.
    static func titleMatches(_ title: String, normalizedQuery needle: String) -> Bool {
        var t = title.lowercased()
        if t.hasPrefix("the ") { t = String(t.dropFirst(4)) }
        return normalized(t) == needle
    }

    /// People surfaced from the top movie hits (each paired with its cast in
    /// billing order): first the top-billed cast credited as the searched
    /// character, ordered by their film's vote count (enduring notability, unlike
    /// TMDB's volatile `popularity`); failing that, the lead(s) of the film the
    /// query names.
    static func moviePeople(query: String,
                            films: [(movie: Movie, cast: [Person])],
                            minQueryLength: Int,
                            topBilledPerFilm: Int,
                            leadFallbackCount: Int,
                            leadFallbackMinPopularity: Double) -> [Person] {
        let needle = normalized(query)
        guard needle.count >= minQueryLength, !films.isEmpty else { return [] }

        // 1) Actors credited as the searched character, ordered by their film's
        //    vote count so the most notable portrayal leads. (We scan the broad
        //    set the caller passes, so older-era heroes aren't dropped — only the
        //    final order changes.)
        var order: [Int] = []
        var byPerson: [Int: (person: Person, notability: Int)] = [:]
        for (movie, cast) in films {
            let filmNotability = movie.voteCount ?? 0
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

        // 2) Fallback: the top film's leads when the query names that film but no
        //    character matched (e.g. "ironman" → RDJ, credited only "Tony Stark").
        guard let top = films.first,
              (top.movie.popularity ?? 0) >= leadFallbackMinPopularity,
              titleMatches(top.movie.title, normalizedQuery: needle) else {
            return []
        }
        return Array(top.cast.prefix(leadFallbackCount))
    }

    /// The people shown atop the results: movie matches first (character or
    /// lead), then name matches by popularity, deduped and capped.
    ///
    /// Name matches with neither a profile photo nor at least `namedNoiseFloor`
    /// popularity are dropped: those are non-person TMDB entries (e.g. "Toy Story
    /// Alien"), not obscure-but-real actors, who keep a headshot. Movie matches
    /// (cast) are never filtered — they're legit even at zero popularity.
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
}

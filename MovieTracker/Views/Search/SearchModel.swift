//
//  SearchModel.swift
//  MovieTracker
//
//  Debounced, cancellable search over one query (no scope toggle): movies plus
//  people by name and from the top movie matches (character or lead fallback), via
//  the pure rules in SearchMatching. Also tracks recent search terms across launches.
//

import SwiftUI

@MainActor
@Observable
final class SearchModel {
    var query = ""
    private(set) var movies: [Movie] = []

    /// People matched by name (TMDB person search).
    private(set) var namedPeople: [Person] = []

    /// People surfaced from the top movie matches: actors credited as the
    /// searched character, or the lead(s) of the named film as a fallback.
    private(set) var movieMatchedPeople: [Person] = []

    /// True while a lookup is in flight, so the UI can tell "still loading"
    /// apart from "no matches" and avoid flashing an empty state.
    private(set) var isLoading = false

    /// Placeholder for the search field. Static now that a single query drives
    /// both movie and people results.
    static let placeholder = "Movies, People, etc."

    /// Recent search terms, most-recent first, persisted across launches.
    private(set) var recentSearches: [String] = []

    private var searchTask: Task<Void, Never>?

    /// The last query whose own results were strong (top popularity ≥
    /// `weakMoviePopularity`). Anchors the recall recovery in `search`.
    private var lastStrongQuery = ""

    private let recentsKey = "recentSearches"
    private let maxRecents = 15

    /// Cap on the full ranked people list (the strip previews a few and folds the
    /// rest behind "More"). High enough to hold every real match.
    private let maxFeaturedPeople = 50

    /// Most people shown inline in the strip before folding into "More".
    private let stripPreviewLimit = 8

    /// A name match below this popularity folds under "More" rather than showing
    /// inline (movie matches are always inline), so a title search's namesake noise
    /// folds while real actors stay inline.
    private let inlinePopularityFloor: Float = 1

    /// When nothing clears the notability bar (a pure obscure-name search), still
    /// show this many inline so the strip is never just a bare "More" button.
    private let minInlinePeople = 3

    /// A name match below this popularity AND without a photo is treated as a
    /// non-person TMDB entry ("Toy Story Alien") and dropped.
    private let namedNoiseFloor: Float = 1

    /// How many of the top movie hits to scan for character-name matches. Deep
    /// enough to span a franchise's eras (e.g. all three Spider-Man leads).
    private let roleMatchMovieDepth = 8

    /// Only scan the top-billed cast of each film, so a title-role match lands
    /// the lead(s), not a deep-cast namesake.
    private let topBilledPerFilm = 15

    /// Shortest query we'll character-match, to avoid a generic term like "man"
    /// matching half the cast of every result.
    private let minRoleMatchLength = 4

    /// Shortest query for the lead fallback's PREFIX case (exact matches fire at any
    /// length). Lower than character-matching because it's precise on its own (title
    /// prefix + popularity), so a 3-char prefix already surfaces the stars.
    private let minLeadPrefixLength = 3

    /// A film must have at least this many votes for its cast to surface via a character-name match
    private let minCharacterMatchVotes = 300

    /// TMDB returns a long tail of near-anonymous films (a handful of votes) that
    /// crowd the real results. Films below this vote count are buried at the
    /// bottom of the movie list — still reachable, just out of the way.
    private let movieNoiseVoteFloor = 100

    /// Below this top-result popularity, a query is treated as having found only
    /// obscure films, triggering the spaced-variant retry (see fetchMovies).
    private let weakMoviePopularity = 5.0

    /// When no character matches, surface this many of the named film's leads, so a
    /// title search shows its stars, not just the top-billed one.
    private let leadFallbackCount = 2

    /// The named film must be at least this popular to surface its leads, so an
    /// obscure movie sharing the query's title doesn't put randos in the strip.
    private let leadFallbackMinPopularity = 10.0

    /// Pause after the last keystroke before hitting the network, so typing
    /// doesn't storm the API (the character-match fans out to several requests).
    private let debounce = Duration.milliseconds(300)

    /// People worth surfacing above the movie results: movie matches first
    /// (character or lead), then name matches by popularity. Always shown when
    /// non-empty, so people stay reachable even when their popularity is low.
    var featuredPeople: [Person] {
        SearchMatching.featuredPeople(movieMatched: movieMatchedPeople,
                                      named: namedPeople,
                                      cap: maxFeaturedPeople,
                                      namedNoiseFloor: namedNoiseFloor)
    }

    /// How many featured people the strip shows inline before folding the rest
    /// (low-popularity namesakes) behind the "More" button.
    var featuredPeopleInlineCount: Int {
        SearchMatching.inlinePeopleCount(featuredPeople,
                                         movieMatchedIDs: Set(movieMatchedPeople.map(\.id)),
                                         inlinePopularityFloor: inlinePopularityFloor,
                                         minInline: minInlinePeople,
                                         previewLimit: stripPreviewLimit)
    }

    init() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
    }

    func search(_ rawQuery: String) {
        searchTask?.cancel()

        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            movies = []
            namedPeople = []
            movieMatchedPeople = []
            lastStrongQuery = ""
            isLoading = false
            return
        }

        isLoading = true
        searchTask = Task {
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }

            // Look up movies and people concurrently so one query surfaces both.
            // Each side degrades to empty on its own, so a people-search failure
            // never discards movie results (and vice versa).
            async let movieResults = fetchMovies(query)
            async let peopleResults = fetchPeople(query)
            var movies = await movieResults
            let people = await peopleResults
            guard !Task.isCancelled else { return }

            // Recall recovery: TMDB's incremental search is erratic, so mid-typing a
            // multi-word title the real film can drop out. If this weak keystroke
            // relates to a previously-strong query, re-run that anchor and keep its
            // results — but only if the query still leads to the anchor's top film,
            // so typing toward a different title self-corrects to its real results.
            let originalStrong = isStrong(movies)
            if !originalStrong,
               SearchMatching.shouldTryAnchorRecovery(query: query,
                                                      lastStrongQuery: lastStrongQuery,
                                                      minLength: minRoleMatchLength) {
                let recovered = await fetchMovies(lastStrongQuery)
                guard !Task.isCancelled else { return }
                let needle = SearchMatching.normalized(SearchMatching.articleStripped(query))
                if isStrong(recovered), let top = recovered.first,
                   SearchMatching.topFilmLeadsApply(topTitle: top.title, normalizedQuery: needle,
                                                    minQueryLength: minLeadPrefixLength) {
                    movies = recovered
                }
            }

            // Resolve movie-matched people BEFORE publishing, so results land in one
            // complete update instead of pairing new movies with the previous query's
            // people (a "wrong people" flash) and updating again. Old results stay on
            // screen until this single commit, so there's no blank between queries.
            let moviePeople = await moviePeople(query: query, in: movies)
            guard !Task.isCancelled else { return }

            self.movies = movies
            self.namedPeople = people
            self.movieMatchedPeople = moviePeople
            // Advance the anchor only when the typed query itself was strong, so
            // recovery always re-runs a real query, never a recovered one.
            if originalStrong { self.lastStrongQuery = query }
            self.isLoading = false
        }
    }

    /// Whether a result set has a genuinely relevant hit up top, versus only the
    /// obscure long tail TMDB returns for a partial/compressed query.
    private func isStrong(_ movies: [Movie]) -> Bool {
        (movies.first?.popularity ?? 0) >= weakMoviePopularity
    }

    /// Movie results for the query. TMDB's title search is space-sensitive, so a
    /// compressed hero name like "ironman" finds only obscure films while "iron
    /// man" finds the Marvel ones. When the compact query looks weak, also search
    /// a spaced variant and merge the (more relevant) spaced results in front.
    private func fetchMovies(_ query: String) async -> [Movie] {
        var results = await titleMovies(query)

        // A few franchises whose iconic entries the title search misses because
        // their titles don't contain the query (e.g. "The Dark Knight" for
        // "batman", "Man of Steel" for "superman"). Merge those collections in.
        if let collectionIDs = Self.curatedCollections[query] {
            var seen = Set(results.map(\.id))
            for id in collectionIDs {
                let parts = (try? await TMDBWrapper.getCollection(id: id)) ?? []
                results += parts.filter { seen.insert($0.id).inserted }
            }
            // The popularity ranking below floats the iconic entries (e.g. The Dark
            // Knight) ahead of the long tail of title matches, so no extra sort here.
        }

        // Rank for display: notable films first by current popularity, low-vote
        // noise sunk below (kept reachable, not dropped).
        return SearchMatching.rankedForDisplay(results, minVotes: movieNoiseVoteFloor)
    }

    /// Title-based movie results. TMDB misses films spelled unlike its index, so we
    /// also search alternate spellings and merge them in front: an interpunct variant
    /// for separator/bullet titles, plus — when the plain results look weak — the
    /// spaced hero variant for a compressed name. Noise a variant adds sinks in
    /// `rankedForDisplay`.
    private func titleMovies(_ query: String) async -> [Movie] {
        let primary = await rawMovieSearch(query)

        var alternates: [String] = []
        if let bullet = SearchMatching.interpunctVariant(of: query) {
            alternates.append(bullet)
        }
        if (primary.first?.popularity ?? 0) < weakMoviePopularity,
           let spaced = SearchMatching.spacedVariant(of: query) {
            alternates.append(spaced)
        }
        guard !alternates.isEmpty else { return primary }

        var seen = Set<Int>()
        var results: [Movie] = []
        for alternate in alternates {
            for movie in await rawMovieSearch(alternate) where seen.insert(movie.id).inserted {
                results.append(movie)
            }
        }
        results += primary.filter { seen.insert($0.id).inserted }
        return results
    }

    /// Curated franchise collections to fold into a query's movie results, keyed
    /// by the (lowercased) query. For franchises where TMDB's title search omits
    /// iconic entries whose titles don't contain the query.
    private static let curatedCollections: [String: [Int]] = [
        "batman": [263],      // The Dark Knight Collection (adds The Dark Knight[, Rises])
        "superman": [209131], // Man of Steel Collection (adds Man of Steel, BvS)
    ]

    private func rawMovieSearch(_ query: String) async -> [Movie] {
        do {
            return try await TMDBWrapper.searchForMovies(query: query).items
        } catch {
            if !Task.isCancelled { print("Movie search error: \(error)") }
            return []
        }
    }

    private func fetchPeople(_ query: String) async -> [Person] {
        do {
            return try await TMDBWrapper.searchForPeople(query: query).items
        } catch {
            if !Task.isCancelled { print("People search error: \(error)") }
            return []
        }
    }

    /// People surfaced from the top movie hits. Fetches the casts, then defers
    /// the matching and ranking to the network-free `SearchMatching`.
    private func moviePeople(query: String, in movies: [Movie]) async -> [Person] {
        guard !movies.isEmpty else { return [] }

        // Character-matching needs a non-generic query length; the lead fallback
        // applies on an exact title (any length, so "300" works) or a title prefix
        // (so "odysse" already surfaces The Odyssey's cast). Skip the cast fetch
        // only when neither path could possibly apply.
        let needle = SearchMatching.normalized(SearchMatching.articleStripped(query))
        let canCharacterMatch = needle.count >= minRoleMatchLength
        let canLeadFallback = movies.first.map {
            SearchMatching.topFilmLeadsApply(topTitle: $0.title, normalizedQuery: needle,
                                             minQueryLength: minLeadPrefixLength)
        } ?? false
        guard canCharacterMatch || canLeadFallback else { return [] }

        let topMovies = Array(movies.prefix(roleMatchMovieDepth))
        // Fetch casts concurrently but reassemble in movie order.
        let casts = await withTaskGroup(of: (Int, [Person]).self) { group in
            for (index, movie) in topMovies.enumerated() {
                group.addTask {
                    (index, (try? await TMDBWrapper.movieCast(id: movie.id)) ?? [])
                }
            }
            var buffer = Array(repeating: [Person](), count: topMovies.count)
            for await (index, cast) in group { buffer[index] = cast }
            return buffer
        }

        let films = zip(topMovies, casts).map { (movie: $0, cast: $1) }
        return SearchMatching.moviePeople(query: query,
                                          films: films,
                                          minQueryLength: minRoleMatchLength,
                                          leadPrefixMinLength: minLeadPrefixLength,
                                          topBilledPerFilm: topBilledPerFilm,
                                          minCharacterMatchVotes: minCharacterMatchVotes,
                                          leadFallbackCount: leadFallbackCount,
                                          leadFallbackMinPopularity: leadFallbackMinPopularity)
    }

    // MARK: - Recent searches

    /// Records the current query as a recent search, moving it to the top and
    /// removing any duplicate. Call when the user commits a search (submits) or
    /// opens a result.
    func commit() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > maxRecents {
            recentSearches = Array(recentSearches.prefix(maxRecents))
        }
        persistRecents()
    }

    /// Re-runs a saved search term by populating the field, exactly as if the
    /// user had retyped it, and elevates it to the top of the recents list.
    func selectRecent(_ term: String) {
        query = term
        search(term)
        commit()
    }

    func removeRecent(_ term: String) {
        recentSearches.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        persistRecents()
    }

    func clearRecents() {
        recentSearches = []
        persistRecents()
    }

    private func persistRecents() {
        UserDefaults.standard.set(recentSearches, forKey: recentsKey)
    }
}

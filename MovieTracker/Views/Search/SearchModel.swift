//
//  SearchModel.swift
//  MovieTracker
//
//  Debounced, cancellable search that looks up movies and people together from
//  a single query — no scope toggle. People surface two ways: by name (TMDB
//  person search) and from the top movie matches — either the actors credited as
//  the searched character (so "spiderman" → the Spider-Man actors) or, when no
//  character matches, the lead(s) of the film the query names (so "ironman" → the
//  Iron Man lead, credited only as "Tony Stark"). Also tracks recent search
//  terms, persisted across launches.
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

    private let recentsKey = "recentSearches"
    private let maxRecents = 15

    /// Most people ever shown in the strip above the movie results.
    private let maxFeaturedPeople = 12

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

    /// Below this top-result popularity, a query is treated as having found only
    /// obscure films, triggering the spaced-variant retry (see fetchMovies).
    private let weakMoviePopularity = 5.0

    /// When no character matches, surface this many of the named film's leads
    /// (just the star — a second lead tends to be a co-star, not the hero).
    private let leadFallbackCount = 1

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
            let (movies, people) = await (movieResults, peopleResults)

            guard !Task.isCancelled else { return }
            self.movies = movies
            self.namedPeople = people

            // Surface actors from the top movie matches.
            let moviePeople = await moviePeople(query: query, in: movies)
            guard !Task.isCancelled else { return }
            self.movieMatchedPeople = moviePeople
            self.isLoading = false
        }
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
            // Read the franchise as a notability-ranked "greatest films" list, so
            // iconic entries (e.g. The Dark Knight) lead rather than trailing the
            // long tail of title matches.
            results.sort { ($0.voteCount ?? 0) > ($1.voteCount ?? 0) }
        }
        return results
    }

    /// Title-based movie results, with the spaced-variant retry for compressed
    /// hero names (see the class notes).
    private func titleMovies(_ query: String) async -> [Movie] {
        let primary = await rawMovieSearch(query)
        guard (primary.first?.popularity ?? 0) < weakMoviePopularity,
              let spaced = SearchMatching.spacedVariant(of: query) else {
            return primary
        }

        let alternate = await rawMovieSearch(spaced)
        guard !alternate.isEmpty else { return primary }

        var seen = Set<Int>()
        return (alternate + primary).filter { seen.insert($0.id).inserted }
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
        guard SearchMatching.normalized(query).count >= minRoleMatchLength,
              !movies.isEmpty else { return [] }

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
                                          topBilledPerFilm: topBilledPerFilm,
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

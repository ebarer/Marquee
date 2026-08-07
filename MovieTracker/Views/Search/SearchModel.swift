//
//  SearchModel.swift
//  MovieTracker
//
//  Debounced, cancellable search over one query; matching/ranking in SearchMatching.
//

import SwiftUI

@MainActor
@Observable
final class SearchModel {
    var query = ""
    private(set) var movies: [Movie] = []

    private(set) var namedPeople: [Person] = []
    private(set) var movieMatchedPeople: [Person] = []
    private(set) var isLoading = false

    static let placeholder = "Movies, People, etc."

    private(set) var recentSearches: [String] = []

    private var searchTask: Task<Void, Never>?

    /// The last query whose own results were strong; anchors recall recovery in `search`.
    private var lastStrongQuery = ""

    private let recentsKey = "recentSearches"
    private let maxRecents = 15
    private let maxFeaturedPeople = 50
    private let stripPreviewLimit = 8
    private let inlinePopularityFloor: Float = 1
    private let minInlinePeople = 3
    private let namedNoiseFloor: Float = 1
    private let roleMatchMovieDepth = 8
    private let topBilledPerFilm = 15
    private let minRoleMatchLength = 4
    private let minLeadPrefixLength = 3
    private let minCharacterMatchVotes = 300
    private let movieNoiseVoteFloor = 100
    private let weakMoviePopularity = 5.0
    private let leadFallbackCount = 2
    private let leadFallbackMinPopularity = 10.0
    private let debounce = Duration.milliseconds(300)

    var featuredPeople: [Person] {
        SearchMatching.featuredPeople(movieMatched: movieMatchedPeople,
                                      named: namedPeople,
                                      cap: maxFeaturedPeople,
                                      namedNoiseFloor: namedNoiseFloor)
    }

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

            // Each side degrades to empty on its own, so one search's failure
            // never discards the other's results.
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
        }

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

    /// For franchises where TMDB's title search omits iconic entries whose titles
    /// don't contain the query, keyed by the lowercased query.
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

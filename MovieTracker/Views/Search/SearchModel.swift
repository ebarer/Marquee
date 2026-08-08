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
    private(set) var shows: [Show] = []
    /// Movies and shows interlaced, ranked by popularity so the strongest match leads.
    private(set) var results: [MediaRef] = []

    private(set) var namedPeople: [Person] = []
    private(set) var movieMatchedPeople: [Person] = []
    /// Recurring cast of the top matching show, surfaced in the People strip like film cast.
    private(set) var showMatchedPeople: [Person] = []
    private(set) var isLoading = false

    static let placeholder = "Movies, TV, People, etc."

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
    private let showNoiseVoteFloor = 10
    private let weakShowPopularity = 5.0
    private let leadFallbackCount = 2
    private let leadFallbackMinPopularity = 10.0
    private let debounce = Duration.milliseconds(300)

    /// Cast surfaced from matched titles: a film's cast plus the top show's recurring cast.
    private var titleMatchedPeople: [Person] { movieMatchedPeople + showMatchedPeople }

    var featuredPeople: [Person] {
        SearchMatching.featuredPeople(movieMatched: titleMatchedPeople,
                                      named: namedPeople,
                                      cap: maxFeaturedPeople,
                                      namedNoiseFloor: namedNoiseFloor)
    }

    var featuredPeopleInlineCount: Int {
        SearchMatching.inlinePeopleCount(featuredPeople,
                                         movieMatchedIDs: Set(titleMatchedPeople.map(\.id)),
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
            shows = []
            results = []
            namedPeople = []
            movieMatchedPeople = []
            showMatchedPeople = []
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
            async let showResults = fetchShows(query)
            var movies = await movieResults
            let people = await peopleResults
            let shows = await showResults
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

            // Resolve title-matched people BEFORE publishing, so results land in one
            // complete update instead of pairing new titles with the previous query's
            // people (a "wrong people" flash) and updating again. Old results stay on
            // screen until this single commit, so there's no blank between queries.
            let moviePeople = await moviePeople(query: query, in: movies)
            let showPeople = await showPeople(in: shows)
            guard !Task.isCancelled else { return }

            self.movies = movies
            self.shows = shows
            self.results = Self.interlaced(movies: movies, shows: shows, query: query,
                                           voteFloor: movieNoiseVoteFloor,
                                           popularityFloor: weakMoviePopularity)
            self.namedPeople = people
            self.movieMatchedPeople = moviePeople
            self.showMatchedPeople = showPeople
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

    /// Shows for the query: trimmed to US-aired/established (or exactly-named) series to cut
    /// TMDB's noisy TV relevance, then ordered most-popular first.
    private func fetchShows(_ query: String) async -> [Show] {
        do {
            let items = try await TMDBWrapper.searchForShows(query: query).items
            let needle = SearchMatching.normalized(SearchMatching.articleStripped(query))
            return SearchMatching.relevantShows(items, normalizedQuery: needle,
                                                voteFloor: showNoiseVoteFloor,
                                                popularityFloor: weakShowPopularity)
                .sorted { ($0.popularity ?? 0) > ($1.popularity ?? 0) }
        } catch {
            if !Task.isCancelled { print("Show search error: \(error)") }
            return []
        }
    }

    /// Movies and shows in one list. Ordering, in order of precedence:
    ///  1. **Notable pool first, obscure pool last.** Low-signal results (`voteCount` below
    ///     `voteFloor` *and* `popularity` below `popularityFloor`) sink beneath every notable
    ///     result regardless of title — since almost every search targets something popular,
    ///     an obscure item is fine to bury (users can scroll). A brand-new trending release
    ///     (few votes but real popularity) escapes the obscure pool.
    ///  2. **Title relevance** within each pool: exact title (so "house" leads with *House*,
    ///     "star wars" with the film), then prefix, then everything else — including relevant
    ///     non-literal matches like "The Dark Knight" for "batman", which stay in the notable
    ///     pool rather than being buried.
    ///  3. Notability (`voteCount`), then popularity, then original order (movies precede shows).
    nonisolated static func interlaced(movies: [Movie], shows: [Show], query: String = "",
                                       voteFloor: Int = 0, popularityFloor: Double = 0) -> [MediaRef] {
        let needle = SearchMatching.normalized(SearchMatching.articleStripped(query))
        let refs = movies.map(MediaRef.movie) + shows.map(MediaRef.show)
        // Relevance capped at 2 (exact/prefix/rest); obscure results add 3 so they trail
        // the whole notable pool while still ordering sensibly among themselves.
        func rank(_ ref: MediaRef) -> Int {
            let relevance = min(SearchMatching.titleRelevance(ref.title, normalizedQuery: needle), 2)
            let obscure = ref.voteCount < voteFloor && ref.popularity < popularityFloor
            return obscure ? relevance + 3 : relevance
        }
        return refs.enumerated()
            .sorted { lhs, rhs in
                let (lr, rr) = (rank(lhs.element), rank(rhs.element))
                if lr != rr { return lr < rr }
                if lhs.element.voteCount != rhs.element.voteCount {
                    return lhs.element.voteCount > rhs.element.voteCount
                }
                if lhs.element.popularity != rhs.element.popularity {
                    return lhs.element.popularity > rhs.element.popularity
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// Recurring cast of the top matching show, surfaced in the People strip — only when
    /// that show is a strong, front-of-results match (mirrors how a film surfaces its cast).
    private func showPeople(in shows: [Show]) async -> [Person] {
        guard let top = shows.first, (top.popularity ?? 0) >= weakMoviePopularity else { return [] }
        guard let full = try? await TMDBWrapper.getShow(id: top.id) else { return [] }
        return Array(full.recurringCast.prefix(topBilledPerFilm))
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

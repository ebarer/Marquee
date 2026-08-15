//
//  SearchModel.swift
//  MovieTracker
//
//  Debounced, cancellable search over one query. A SearchPolicy does the fetching,
//  augmenting and ranking (see Engine/); the model drives it, recovers results
//  TMDB drops mid-type, tracks recents, and publishes for the view.
//

import SwiftUI

@MainActor
@Observable
final class SearchModel {
    var query = ""
    private(set) var movies: [Movie] = []
    private(set) var shows: [Show] = []
    /// Movies and shows interlaced and ranked — the list the view renders.
    private(set) var results: [MediaRef] = []

    private(set) var namedPeople: [Person] = []
    /// Cast surfaced from matched titles: a film's leads/character matches plus the
    /// top show's recurring cast.
    private(set) var castMatchedPeople: [Person] = []
    private(set) var isLoading = false

    static let placeholder = "Movies, TV, People, etc."

    private(set) var recentSearches: [String] = []

    private let policy: SearchPolicy
    private let provider: SearchProvider
    private var searchTask: Task<Void, Never>?

    /// The last query whose own results were strong; anchors recall recovery below.
    private var lastStrongQuery = ""

    private let recentsKey = "recentSearches"
    private let maxRecents = 15
    private let maxFeaturedPeople = 50
    private let stripPreviewLimit = 8
    private let inlinePopularityFloor: Float = 1
    private let minInlinePeople = 3
    private let namedNoiseFloor: Float = 1
    private let minRoleMatchLength = 4
    private let minLeadPrefixLength = 3
    private let weakMoviePopularity = 5.0
    private let debounce = Duration.milliseconds(300)

    var featuredPeople: [Person] {
        SearchMatching.featuredPeople(castMatched: castMatchedPeople,
                                      named: namedPeople,
                                      cap: maxFeaturedPeople,
                                      namedNoiseFloor: namedNoiseFloor)
    }

    var featuredPeopleInlineCount: Int {
        SearchMatching.inlinePeopleCount(featuredPeople,
                                         castMatchedIDs: Set(castMatchedPeople.map(\.id)),
                                         inlinePopularityFloor: inlinePopularityFloor,
                                         minInline: minInlinePeople,
                                         previewLimit: stripPreviewLimit)
    }

    init(policy: SearchPolicy = .standard, provider: SearchProvider = TMDBSearchProvider()) {
        self.policy = policy
        self.provider = provider
        recentSearches = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
    }

    func search(_ rawQuery: String) {
        searchTask?.cancel()

        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            clear()
            return
        }

        isLoading = true
        searchTask = Task {
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }

            var result = await policy.run(query: query, using: provider)
            guard !Task.isCancelled else { return }

            // Recall recovery: TMDB's incremental search is erratic, so the real match can
            // drop mid-type. Re-run the last strong anchor while the query still leads to it.
            let originalStrong = isStrong(result)
            if !originalStrong,
               SearchMatching.shouldTryAnchorRecovery(query: query,
                                                      lastStrongQuery: lastStrongQuery,
                                                      minLength: minRoleMatchLength) {
                let recovered = await policy.run(query: lastStrongQuery, using: provider)
                guard !Task.isCancelled else { return }
                let needle = SearchMatching.normalized(SearchMatching.articleStripped(query))
                if isStrong(recovered), let top = recovered.movies.first,
                   SearchMatching.topFilmLeadsApply(topTitle: top.title, normalizedQuery: needle,
                                                    minQueryLength: minLeadPrefixLength) {
                    result = recovered
                }
            }

            publish(result)
            // Advance the anchor only when the typed query itself was strong, so
            // recovery always re-runs a real query, never a recovered one.
            if originalStrong { lastStrongQuery = query }
        }
    }

    private func isStrong(_ result: SearchResults) -> Bool {
        (result.movies.first?.popularity ?? 0) >= weakMoviePopularity
    }

    private func publish(_ result: SearchResults) {
        movies = result.movies
        shows = result.shows
        results = result.results
        namedPeople = result.namedPeople
        castMatchedPeople = result.castPeople
        isLoading = false
    }

    private func clear() {
        movies = []
        shows = []
        results = []
        namedPeople = []
        castMatchedPeople = []
        lastStrongQuery = ""
        isLoading = false
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

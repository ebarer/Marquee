//
//  SearchModel.swift
//  MovieTracker
//
//  Debounced, cancellable search over one query; a `SearchPolicy` does the fetching and ranking.
//

import SwiftUI

@MainActor
@Observable
final class SearchModel {
    var query = ""
    private(set) var movies: [Movie] = []
    private(set) var shows: [Show] = []
    private(set) var results: [MediaRef] = []

    private(set) var namedPeople: [Person] = []
    private(set) var castMatchedPeople: [Person] = []
    private(set) var isLoading = false

    static let placeholder = "Movies, TV, People, etc."

    private(set) var recentSearches: [RecentSearch] = []

    private let policy: SearchPolicy
    private let provider: SearchProvider
    private var searchTask: Task<Void, Never>?

    private var lastStrongQuery = ""

    private let recentsKey = "recentSearchResults"
    private let maxRecents = 15
    private let maxFeaturedPeople = 50
    private let stripPreviewLimit = 8
    private let inlinePopularityFloor: Float = 1
    private let minInlinePeople = 3
    private let namedNoiseFloor: Float = 1
    private let titleOwnsVoteFloor = 300
    private let minRoleMatchLength = 4
    private let minLeadPrefixLength = 3
    private let weakMoviePopularity = 5.0
    private let debounce = Duration.milliseconds(300)

    var featuredPeople: [Person] {
        SearchMatching.featuredPeople(castMatched: castMatchedPeople,
                                      named: namedPeople,
                                      cap: maxFeaturedPeople,
                                      namedNoiseFloor: namedNoiseFloor,
                                      query: query,
                                      titleOwnsQuery: titleOwnsQuery)
    }

    // A notable exact title owns the query: "dune" means the film, not an actor named Dune.
    private var titleOwnsQuery: Bool {
        let needle = SearchMatching.normalized(SearchMatching.articleStripped(query))
        guard !needle.isEmpty else { return false }
        let titled = movies.prefix(5).map { ($0.title, $0.voteCount ?? 0) }
            + shows.prefix(5).map { ($0.name, $0.voteCount ?? 0) }
        return titled.contains {
            $0.1 >= titleOwnsVoteFloor
                && SearchMatching.titleMatches($0.0, normalizedQuery: needle)
        }
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
        recentSearches = Self.loadRecents(forKey: recentsKey)
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

            // TMDB's incremental search is erratic and the real match can drop mid-type, so re-run the last
            // strong anchor while the query still leads to it.
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
            // Advance the anchor only when the typed query was strong, so recovery re-runs a real query.
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

    /// Records an opened result. A search with nothing tapped was abandoned and is not stored.
    func recordVisit(_ value: AnyHashable) {
        guard let item = RecentSearch(navigationValue: value) else { return }
        // The iPad shell routes every push through here, so a tap made outside search only
        // counts when it re-opens a recent.
        let isSearching = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard isSearching || recentSearches.contains(where: { $0.id == item.id }) else { return }

        recentSearches.removeAll { $0.id == item.id }
        recentSearches.insert(item, at: 0)
        if recentSearches.count > maxRecents {
            recentSearches = Array(recentSearches.prefix(maxRecents))
        }
        persistRecents()
    }

    func removeRecent(_ item: RecentSearch) {
        recentSearches.removeAll { $0.id == item.id }
        persistRecents()
    }

    func clearRecents() {
        recentSearches = []
        persistRecents()
    }

    private func persistRecents() {
        let data = try? JSONEncoder().encode(recentSearches)
        UserDefaults.standard.set(data, forKey: recentsKey)
    }

    private static func loadRecents(forKey key: String) -> [RecentSearch] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode([RecentSearch].self, from: data) else { return [] }
        return stored
    }
}

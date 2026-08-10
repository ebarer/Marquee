//
//  SearchModelTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@MainActor
@Suite(.serialized) struct SearchModelTests {
    init() { UserDefaults.standard.removeObject(forKey: "recentSearches") }

    @Test func commitInsertsMostRecentFirstAndDedupesCaseInsensitively() {
        let model = SearchModel()
        model.query = "Matrix"; model.commit()
        model.query = "Inception"; model.commit()
        model.query = "matrix"; model.commit()  // dupe of "Matrix"
        #expect(model.recentSearches == ["matrix", "Inception"])
    }

    @Test func commitIgnoresBlankQuery() {
        let model = SearchModel()
        model.query = "   "; model.commit()
        #expect(model.recentSearches.isEmpty)
    }

    @Test func recentsAreCappedAtFifteen() {
        let model = SearchModel()
        for i in 1...20 { model.query = "q\(i)"; model.commit() }
        #expect(model.recentSearches.count == 15)
        #expect(model.recentSearches.first == "q20")
    }

    @Test func removeAndClearRecents() {
        let model = SearchModel()
        model.query = "A"; model.commit()
        model.query = "B"; model.commit()
        model.removeRecent("a")  // case-insensitive
        #expect(model.recentSearches == ["B"])
        model.clearRecents()
        #expect(model.recentSearches.isEmpty)
    }

    @Test func recentsPersistAcrossInstances() {
        let first = SearchModel()
        first.query = "Persisted"; first.commit()
        let second = SearchModel()
        #expect(second.recentSearches == ["Persisted"])
    }

    @Test func emptyQueryClearsResults() {
        let model = SearchModel()
        model.search("")
        #expect(model.movies.isEmpty)
        #expect(model.results.isEmpty)
        #expect(model.namedPeople.isEmpty)
        #expect(model.castMatchedPeople.isEmpty)
        #expect(model.featuredPeople.isEmpty)
        #expect(model.isLoading == false)
    }

    @Test func placeholderText() {
        #expect(SearchModel.placeholder == "Movies, TV, People, etc.")
    }
}

@Suite struct SearchInterlaceTests {
    private func movie(_ id: Int, _ pop: Double) -> Movie {
        var m = Movie(id: id, title: "M\(id)")
        m.popularity = pop
        return m
    }

    private func show(_ id: Int, _ pop: Double) -> Show {
        var s = Show(id: id, name: "S\(id)")
        s.popularity = pop
        return s
    }

    @Test func rankedByPopularityWhenRelevanceEqual() {
        // With no query, all titles tie on relevance, so popularity decides.
        let result = SearchMatching.interlaced(
            movies: [movie(1, 20), movie(2, 5)],
            shows: [show(9, 100)]
        )
        #expect(result.map(\.id) == ["show-9", "movie-1", "movie-2"])
    }

    @Test func tiesKeepOriginalOrderMoviesBeforeShows() {
        let result = SearchMatching.interlaced(
            movies: [movie(1, 10)],
            shows: [show(9, 10)]
        )
        // Equal relevance/popularity → stable: the movie (earlier index) stays first.
        #expect(result.map(\.id) == ["movie-1", "show-9"])
    }

    @Test func emptyInputsProduceEmpty() {
        #expect(SearchMatching.interlaced(movies: [], shows: []).isEmpty)
    }

    @Test func exactTitleMatchLeadsRegardlessOfPopularity() {
        var film = Movie(id: 1, title: "Star Wars"); film.popularity = 30; film.voteCount = 20_000
        var series = Show(id: 9, name: "Star Wars: The Clone Wars"); series.popularity = 90; series.voteCount = 3_000
        // The exactly-named film beats the more-popular prefix-matching series.
        let result = SearchMatching.interlaced(movies: [film], shows: [series], query: "star wars")
        #expect(result.first?.id == "movie-1")
    }

    @Test func strongTitleMatchTierLeadsThenNotabilityWithin() {
        // "house": strong matches (exact/prefix) lead over the weak "Road House" (a title
        // word merely starts with it), even though Road House has more votes. Within the
        // strong tier, notability orders: *House* (exact, 9k) then "House of Wax" (prefix).
        var series = Show(id: 9, name: "House"); series.popularity = 40; series.voteCount = 9_000
        var wax = Movie(id: 1, title: "House of Wax"); wax.popularity = 20; wax.voteCount = 800
        var road = Movie(id: 2, title: "Road House"); road.popularity = 95; road.voteCount = 5_000
        let result = SearchMatching.interlaced(movies: [wax, road], shows: [series], query: "house")
        #expect(result.map(\.id) == ["show-9", "movie-1", "movie-2"])
    }

    @Test func obscureExactMatchSinksBelowNotableResults() {
        var popular = Movie(id: 1, title: "Star Wars"); popular.voteCount = 20_000; popular.popularity = 80
        var junk = Movie(id: 2, title: "Star Wars"); junk.voteCount = 3; junk.popularity = 0.5
        // Both exact matches, but the obscure one drops beneath the notable pool.
        let result = SearchMatching.interlaced(movies: [junk, popular], shows: [], query: "star wars",
                                            voteFloor: 100, popularityFloor: 5)
        #expect(result.map(\.id) == ["movie-1", "movie-2"])
    }

    @Test func popularNonMatchOutranksObscureTitleMatch() {
        var dark = Movie(id: 1, title: "The Dark Knight"); dark.voteCount = 30_000; dark.popularity = 80
        var fan = Movie(id: 2, title: "Batman Fan Edit"); fan.voteCount = 4; fan.popularity = 0.3
        // Popular real result (no literal match) beats an obscure prefix match.
        let result = SearchMatching.interlaced(movies: [dark, fan], shows: [], query: "batman",
                                            voteFloor: 100, popularityFloor: 5)
        #expect(result.map(\.id) == ["movie-1", "movie-2"])
    }

    @Test func trendingLowVoteReleaseEscapesObscurePool() {
        var fresh = Movie(id: 1, title: "Brand New"); fresh.voteCount = 10; fresh.popularity = 60
        var stale = Movie(id: 2, title: "Nobody Watched"); stale.voteCount = 2; stale.popularity = 0.2
        // Few votes but real popularity → still notable; truly obscure item sinks.
        let result = SearchMatching.interlaced(movies: [stale, fresh], shows: [], query: "",
                                            voteFloor: 100, popularityFloor: 5)
        #expect(result.map(\.id) == ["movie-1", "movie-2"])
    }

    @Test func franchiseSiblingRanksAsStrongMatchByNotability() {
        // "batman": "The Dark Knight" has no literal match but is a franchise sibling
        // (relatedMovieIDs), so it joins the strong tier and — being the most-voted —
        // leads the exactly-titled "Batman". "Unrelated" (no match) trails.
        var exact = Movie(id: 1, title: "Batman"); exact.voteCount = 8_000; exact.popularity = 40
        var dark = Movie(id: 2, title: "The Dark Knight"); dark.voteCount = 30_000; dark.popularity = 80
        var other = Movie(id: 3, title: "Unrelated"); other.voteCount = 50; other.popularity = 5
        let result = SearchMatching.interlaced(movies: [other, dark, exact], shows: [], query: "batman",
                                               relatedMovieIDs: [2])
        #expect(result.map(\.id) == ["movie-2", "movie-1", "movie-3"])
    }

    @Test func relevantShowsDropsForeignAndFeaturetteJunk() {
        func s(_ id: Int, _ name: String, us: Bool, votes: Int, pop: Double) -> Show {
            var show = Show(id: id, name: name)
            show.originCountry = us ? ["US"] : ["JP"]
            show.voteCount = votes; show.popularity = pop
            return show
        }
        let shows = [
            s(1, "Andor", us: true, votes: 5_000, pop: 80),                       // US, established
            s(2, "Andor: A Disney+ Day Special Look", us: true, votes: 2, pop: 1), // US featurette
            s(3, "Andro Melos", us: false, votes: 3, pop: 1),                      // foreign junk
            s(4, "Squid Game", us: false, votes: 9_000, pop: 90),                  // foreign, not typed
        ]
        let kept = SearchMatching.relevantShows(shows, normalizedQuery: SearchMatching.normalized("andor"),
                                                voteFloor: 10, popularityFloor: 5)
        #expect(kept.map(\.id) == [1])
    }

    @Test func relevantShowsKeepsExactlyNamedForeignShow() {
        var show = Show(id: 4, name: "Squid Game")
        show.originCountry = ["KR"]; show.voteCount = 9_000; show.popularity = 90
        let kept = SearchMatching.relevantShows([show], normalizedQuery: SearchMatching.normalized("squid game"),
                                                voteFloor: 10, popularityFloor: 5)
        #expect(kept.map(\.id) == [4])
    }
}

//
//  SearchInterlaceTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct SearchInterlaceTests {
    private func movie(_ id: Int, _ pop: Double) -> Movie {
        var movie = Movie(id: id, title: "M\(id)")
        movie.popularity = pop
        return movie
    }

    private func show(_ id: Int, _ pop: Double) -> Show {
        var show = Show(id: id, name: "S\(id)")
        show.popularity = pop
        return show
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
        // "house": strong matches (exact/prefix) lead the weak "Road House" despite its
        // votes, and notability orders within that tier — *House* then "House of Wax".
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

    /// The bar a new release clears to lead — TMDB's popular-list median in production.
    private let leadFloor: Double = 250

    private func dated(_ id: Int, _ title: String, votes: Int, pop: Double,
                       daysAgo: Int, now: Date) -> Movie {
        var movie = Movie(id: id, title: title)
        movie.voteCount = votes
        movie.popularity = pop
        movie.releaseDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)
        return movie
    }

    @Test func phenomenonInReleaseNowLeadsTheOlderFranchiseEntries() {
        let now = Date()
        // A fraction of the catalogue's votes, but the most popular title anywhere —
        // it's what the query means today.
        let fresh = dated(1, "Spider-Man: Brand New Day", votes: 1_600, pop: 1_150, daysAgo: 14, now: now)
        let classic = dated(2, "Spider-Man: No Way Home", votes: 22_000, pop: 640, daysAgo: 1_800, now: now)
        let result = SearchMatching.interlaced(movies: [classic, fresh], shows: [], query: "spiderman",
                                               voteFloor: 100, popularityFloor: 5, now: now,
                                               leadPopularityFloor: leadFloor)
        #expect(result.map(\.id) == ["movie-1", "movie-2"])
    }

    @Test func merelyPopularNewReleaseDoesNotDisplaceTheClassic() {
        let now = Date()
        // Tops its own franchise, but nowhere near the popular list — the original stands.
        let fresh = dated(1, "Avatar Aang: The Last Airbender", votes: 820, pop: 151, daysAgo: 20, now: now)
        let classic = dated(2, "Avatar", votes: 34_000, pop: 34, daysAgo: 6_000, now: now)
        let result = SearchMatching.interlaced(movies: [fresh, classic], shows: [], query: "avatar",
                                               voteFloor: 100, popularityFloor: 5, now: now,
                                               leadPopularityFloor: leadFloor)
        #expect(result.map(\.id) == ["movie-2", "movie-1"])
    }

    @Test func barelyRatedNewReleaseDoesNotLead() {
        let now = Date()
        // Popular for its size and over the lead floor, but under the vote floor.
        let short = dated(1, "Star Wars: Visions", votes: 17, pop: 900, daysAgo: 8, now: now)
        let classic = dated(2, "Star Wars", votes: 22_000, pop: 34, daysAgo: 14_600, now: now)
        let result = SearchMatching.interlaced(movies: [short, classic], shows: [], query: "star wars",
                                               voteFloor: 100, popularityFloor: 5, now: now,
                                               leadPopularityFloor: leadFloor)
        #expect(result.map(\.id) == ["movie-2", "movie-1"])
    }

    @Test func newReleaseThatIsNotTheMostPopularStaysRankedByVotes() {
        let now = Date()
        let fresh = dated(1, "Dune: Part Three", votes: 900, pop: 260, daysAgo: 10, now: now)
        let classic = dated(2, "Dune", votes: 15_000, pop: 400, daysAgo: 1_800, now: now)
        let result = SearchMatching.interlaced(movies: [fresh, classic], shows: [], query: "dune",
                                               voteFloor: 100, popularityFloor: 5, now: now,
                                               leadPopularityFloor: leadFloor)
        #expect(result.map(\.id) == ["movie-2", "movie-1"])
    }

    @Test func withoutABenchmarkNothingIsPromoted() {
        let now = Date()
        let fresh = dated(1, "Spider-Man: Brand New Day", votes: 1_600, pop: 1_150, daysAgo: 14, now: now)
        let classic = dated(2, "Spider-Man: No Way Home", votes: 22_000, pop: 640, daysAgo: 1_800, now: now)
        // Offline, the benchmark is unavailable — ranking falls back to vote count.
        let result = SearchMatching.interlaced(movies: [classic, fresh], shows: [], query: "spiderman",
                                               voteFloor: 100, popularityFloor: 5, now: now)
        #expect(result.map(\.id) == ["movie-2", "movie-1"])
    }

    @Test func franchiseSiblingRanksAsStrongMatchByNotability() {
        // "batman": "The Dark Knight" has no literal match but is a franchise sibling, so it
        // joins the strong tier and, being most-voted, leads the exactly-titled "Batman".
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

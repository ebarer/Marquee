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

    @Test func strongTitleMatchLeadsComparablyNotableWeakMatch() {
        // "house": a title-leading match beats the weak "Road House" at a comparable level of
        // notability (6× the votes isn't enough), and notability orders the strong matches.
        var series = Show(id: 9, name: "House"); series.popularity = 40; series.voteCount = 9_000
        var wax = Movie(id: 1, title: "House of Wax"); wax.popularity = 20; wax.voteCount = 800
        var road = Movie(id: 2, title: "Road House"); road.popularity = 95; road.voteCount = 5_000
        let result = SearchMatching.interlaced(movies: [wax, road], shows: [series], query: "house")
        #expect(result.map(\.id) == ["show-9", "movie-1", "movie-2"])
    }

    @Test func overwhelminglyNotableWeakMatchOutranksNicheStrongMatch() {
        // "dragon": the phenomenon named late in its title leads the obscure films the query
        // prefixes — the notability gap is orders of magnitude, not a few times over.
        var hotd = Show(id: 9, name: "House of the Dragon"); hotd.voteCount = 6_951; hotd.popularity = 415
        var striker = Show(id: 8, name: "Dragon Striker"); striker.voteCount = 20; striker.popularity = 8
        var eyes = Movie(id: 1, title: "Dragon Eyes"); eyes.voteCount = 205; eyes.popularity = 2.8
        var httyd = Movie(id: 2, title: "How to Train Your Dragon"); httyd.voteCount = 14_590; httyd.popularity = 19
        let result = SearchMatching.interlaced(movies: [eyes, httyd], shows: [hotd, striker],
                                               query: "dragon", voteFloor: 100,
                                               popularityBenchmark: 250)
        #expect(result.map(\.id) == ["show-9", "movie-2", "movie-1", "show-8"])
    }

    @Test func obscureExactMatchSinksBelowNotableResults() {
        var popular = Movie(id: 1, title: "Star Wars"); popular.voteCount = 20_000; popular.popularity = 80
        var junk = Movie(id: 2, title: "Star Wars"); junk.voteCount = 3; junk.popularity = 0.5
        // Both exact matches, so notability alone separates them.
        let result = SearchMatching.interlaced(movies: [junk, popular], shows: [], query: "star wars",
                                            voteFloor: 100)
        #expect(result.map(\.id) == ["movie-1", "movie-2"])
    }

    @Test func popularNonMatchOutranksObscureTitleMatch() {
        var dark = Movie(id: 1, title: "The Dark Knight"); dark.voteCount = 30_000; dark.popularity = 80
        var fan = Movie(id: 2, title: "Batman Fan Edit"); fan.voteCount = 4; fan.popularity = 0.3
        // Popular real result (no literal match) beats an obscure prefix match.
        let result = SearchMatching.interlaced(movies: [dark, fan], shows: [], query: "batman",
                                            voteFloor: 100)
        #expect(result.map(\.id) == ["movie-1", "movie-2"])
    }

    @Test func trendingTitleOutranksTheForgottenOne() {
        var fresh = Movie(id: 1, title: "Brand New"); fresh.voteCount = 10; fresh.popularity = 60
        var stale = Movie(id: 2, title: "Nobody Watched"); stale.voteCount = 2; stale.popularity = 0.2
        // Few votes but real popularity → still the more notable of the two.
        let result = SearchMatching.interlaced(movies: [stale, fresh], shows: [], query: "",
                                            voteFloor: 100, popularityBenchmark: 250)
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
                                               voteFloor: 100, now: now,
                                               popularityBenchmark: leadFloor)
        #expect(result.map(\.id) == ["movie-1", "movie-2"])
    }

    @Test func merelyPopularNewReleaseDoesNotDisplaceTheClassic() {
        let now = Date()
        // Tops its own franchise, but nowhere near the popular list — the original stands.
        let fresh = dated(1, "Avatar Aang: The Last Airbender", votes: 820, pop: 151, daysAgo: 20, now: now)
        let classic = dated(2, "Avatar", votes: 34_000, pop: 34, daysAgo: 6_000, now: now)
        let result = SearchMatching.interlaced(movies: [fresh, classic], shows: [], query: "avatar",
                                               voteFloor: 100, now: now,
                                               popularityBenchmark: leadFloor)
        #expect(result.map(\.id) == ["movie-2", "movie-1"])
    }

    @Test func barelyRatedNewReleaseDoesNotLead() {
        let now = Date()
        // Popular for its size and over the lead floor, but under the vote floor.
        let short = dated(1, "Star Wars: Visions", votes: 17, pop: 900, daysAgo: 8, now: now)
        let classic = dated(2, "Star Wars", votes: 22_000, pop: 34, daysAgo: 14_600, now: now)
        let result = SearchMatching.interlaced(movies: [short, classic], shows: [], query: "star wars",
                                               voteFloor: 100, now: now,
                                               popularityBenchmark: leadFloor)
        #expect(result.map(\.id) == ["movie-2", "movie-1"])
    }

    @Test func newReleaseThatIsNotTheMostPopularStaysRankedByVotes() {
        let now = Date()
        let fresh = dated(1, "Dune: Part Three", votes: 900, pop: 260, daysAgo: 10, now: now)
        let classic = dated(2, "Dune", votes: 15_000, pop: 400, daysAgo: 1_800, now: now)
        let result = SearchMatching.interlaced(movies: [fresh, classic], shows: [], query: "dune",
                                               voteFloor: 100, now: now,
                                               popularityBenchmark: leadFloor)
        #expect(result.map(\.id) == ["movie-2", "movie-1"])
    }

    @Test func withoutABenchmarkNothingIsPromoted() {
        let now = Date()
        let fresh = dated(1, "Spider-Man: Brand New Day", votes: 1_600, pop: 1_150, daysAgo: 14, now: now)
        let classic = dated(2, "Spider-Man: No Way Home", votes: 22_000, pop: 640, daysAgo: 1_800, now: now)
        // Offline, the benchmark is unavailable — ranking falls back to vote count.
        let result = SearchMatching.interlaced(movies: [classic, fresh], shows: [], query: "spiderman",
                                               voteFloor: 100, now: now)
        #expect(result.map(\.id) == ["movie-2", "movie-1"])
    }

    @Test func franchiseSiblingOfAStrongSeedRanksByNotability() {
        // "batman": "The Dark Knight" is a sibling of the title-leading "Batman Begins", so it
        // inherits that footing and, being most-voted, leads the exactly-titled "Batman".
        var exact = Movie(id: 1, title: "Batman"); exact.voteCount = 8_000; exact.popularity = 40
        var dark = Movie(id: 2, title: "The Dark Knight"); dark.voteCount = 30_000; dark.popularity = 80
        var other = Movie(id: 3, title: "Unrelated"); other.voteCount = 50; other.popularity = 5
        let result = SearchMatching.interlaced(movies: [other, dark, exact], shows: [], query: "batman",
                                               relatedMovies: [2: 1])
        #expect(result.map(\.id) == ["movie-2", "movie-1", "movie-3"])
    }

    @Test func franchiseSiblingOfAWeakSeedStaysBelowRealMatches() {
        // "dragon" merely word-matches "The Girl with the Dragon Tattoo", so its Millennium
        // sibling inherits that weaker footing instead of leading the dragon films outright.
        var web = Movie(id: 1, title: "The Girl in the Spider's Web"); web.voteCount = 1_546; web.popularity = 6
        var lee = Movie(id: 2, title: "Dragon: The Bruce Lee Story"); lee.voteCount = 812; lee.popularity = 5
        let result = SearchMatching.interlaced(movies: [web, lee], shows: [], query: "dragon",
                                               relatedMovies: [1: 2])
        #expect(result.map(\.id) == ["movie-2", "movie-1"])
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

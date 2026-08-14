//
//  SearchPolicyTests.swift
//  MarqueeTests
//
//  Exercises the SearchPolicy pipeline end-to-end against a stub provider, so the
//  augmentation behaviours (franchise collection expansion, movies-over-TV ranking)
//  are pinned without hitting live TMDB. Add a scenario here as a regression lands.
//

import Testing
import Foundation
@testable import Marquee

@Suite struct SearchPolicyTests {

    /// Canned SearchProvider: returns whatever the test seeds, empty otherwise.
    struct StubProvider: SearchProvider {
        var movieResults: [String: [Movie]] = [:]
        var showResults: [String: [Show]] = [:]
        var peopleResults: [String: [Person]] = [:]
        var collectionParts: [Int: [Movie]] = [:]
        var movieDetailByID: [Int: Movie] = [:]   // hydrated detail (collection + cast)
        var showDetails: [Int: Show] = [:]

        func movies(matching query: String) async -> [Movie] { movieResults[query] ?? [] }
        func shows(matching query: String) async -> [Show] { showResults[query] ?? [] }
        func people(matching query: String) async -> [Person] { peopleResults[query] ?? [] }
        func collection(id: Int) async -> [Movie] { collectionParts[id] ?? [] }
        func movieDetail(id: Int) async -> Movie? { movieDetailByID[id] }
        func show(id: Int) async -> Show? { showDetails[id] }
    }

    // MARK: - Helpers

    private func movie(_ id: Int, _ title: String, votes: Int, pop: Double,
                       collectionID: Int? = nil) -> Movie {
        var movie = Movie(id: id, title: title)
        movie.voteCount = votes; movie.popularity = pop
        if let collectionID {
            movie.collection = MovieCollection(id: collectionID, name: "Collection",
                                               poster: nil, background: nil)
        }
        return movie
    }

    private func show(_ id: Int, _ name: String, votes: Int, pop: Double, us: Bool = true) -> Show {
        var show = Show(id: id, name: name)
        show.voteCount = votes; show.popularity = pop
        show.originCountry = us ? ["US"] : ["JP"]
        return show
    }

    private func movieTitles(_ results: [MediaRef]) -> [String] {
        results.compactMap {
            if case .movie(let movie) = $0 { return movie.title } else { return nil }
        }
    }

    // MARK: - Franchise collection expansion

    @Test func batmanSurfacesDarkKnightViaCollection() async {
        // "batman" title-matches "Batman Begins", so its Dark Knight Collection siblings
        // surface even without "batman" in their titles. No hardcoded franchise map.
        var stub = StubProvider()
        stub.movieResults["batman"] = [
            movie(272, "Batman Begins", votes: 22_000, pop: 55),
            movie(268, "Batman", votes: 7_000, pop: 40),
        ]
        stub.movieDetailByID[272] = movie(272, "Batman Begins", votes: 22_000, pop: 55, collectionID: 263)
        stub.collectionParts[263] = [
            movie(155, "The Dark Knight", votes: 32_000, pop: 90),
            movie(49026, "The Dark Knight Rises", votes: 20_000, pop: 60),
            movie(272, "Batman Begins", votes: 22_000, pop: 55),
        ]

        let result = await SearchPolicy.standard.run(query: "batman", using: stub)
        let titles = movieTitles(result.results)
        #expect(titles.contains("The Dark Knight"))
        #expect(titles.contains("The Dark Knight Rises"))
        // Most-voted leads regardless of title text.
        #expect(titles.first == "The Dark Knight")
    }

    @Test func supermanSurfacesManOfSteelViaCollection() async {
        // "superman" word-matches "Batman v Superman", which belongs to the Man of
        // Steel Collection — pulling in "Man of Steel".
        var stub = StubProvider()
        stub.movieResults["superman"] = [
            movie(209112, "Batman v Superman: Dawn of Justice", votes: 19_000, pop: 50),
            movie(1452, "Superman Returns", votes: 4_000, pop: 35),
        ]
        stub.movieDetailByID[209112] = movie(209112, "Batman v Superman: Dawn of Justice",
                                             votes: 19_000, pop: 50, collectionID: 209131)
        stub.collectionParts[209131] = [
            movie(49521, "Man of Steel", votes: 15_000, pop: 70),
            movie(209112, "Batman v Superman: Dawn of Justice", votes: 19_000, pop: 50),
        ]

        let result = await SearchPolicy.standard.run(query: "superman", using: stub)
        #expect(movieTitles(result.results).contains("Man of Steel"))
    }

    @Test func siblingOfAWordMatchedSeedDoesNotLeadTheRealMatches() async {
        // "dragon" only word-matches "The Girl with the Dragon Tattoo", so its Millennium
        // sibling inherits that footing instead of leading films that name a dragon.
        var stub = StubProvider()
        stub.movieResults["dragon"] = [
            movie(2_501, "The Girl with the Dragon Tattoo", votes: 7_721, pop: 9),
            movie(9_089, "Dragon: The Bruce Lee Story", votes: 812, pop: 5),
        ]
        stub.movieDetailByID[2_501] = movie(2_501, "The Girl with the Dragon Tattoo",
                                           votes: 7_721, pop: 9, collectionID: 542_461)
        stub.collectionParts[542_461] = [
            movie(446_354, "The Girl in the Spider's Web", votes: 1_546, pop: 6),
            movie(2_501, "The Girl with the Dragon Tattoo", votes: 7_721, pop: 9),
        ]

        let result = await SearchPolicy.standard.run(query: "dragon", using: stub)
        #expect(movieTitles(result.results) == ["The Girl with the Dragon Tattoo",
                                               "Dragon: The Bruce Lee Story",
                                               "The Girl in the Spider's Web"])
    }

    @Test func nonFranchiseQueryDoesNotExpand() async {
        // A notable title match with no collection adds nothing extra.
        var stub = StubProvider()
        stub.movieResults["inception"] = [movie(27205, "Inception", votes: 34_000, pop: 80)]

        let result = await SearchPolicy.standard.run(query: "inception", using: stub)
        #expect(movieTitles(result.results) == ["Inception"])
    }

    // MARK: - Movies over TV

    @Test func spidermanPrioritisesMoviesOverShows() async {
        // The Spider-Man films dominate votes, so they lead — even an exactly-named animated
        // series can't leapfrog the far more notable movies.
        var stub = StubProvider()
        stub.movieResults["spiderman"] = [
            movie(557, "Spider-Man", votes: 18_000, pop: 60),
            movie(634649, "Spider-Man: No Way Home", votes: 20_000, pop: 95),
        ]
        stub.showResults["spiderman"] = [
            show(1978, "Spider-Man", votes: 300, pop: 30),        // exact-named cartoon
            show(60630, "Marvel's Spider-Man", votes: 200, pop: 40),
        ]

        let result = await SearchPolicy.standard.run(query: "spiderman", using: stub)
        let topTwoAreMovies = result.results.prefix(2).allSatisfy(\.isMovie)
        let firstShowIndex = result.results.firstIndex { !$0.isMovie }
        #expect(topTwoAreMovies)
        #expect(firstShowIndex == 2)  // shows only after both films
    }
}

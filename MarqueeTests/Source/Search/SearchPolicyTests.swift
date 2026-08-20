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

    private func person(_ id: Int, _ name: String, _ role: String) -> Person {
        Person(id: id, name: name, role: role, pic: nil, type: .Cast)
    }

    private func namedPerson(_ id: Int, _ name: String, popularity: Float,
                             photo: String? = nil) -> Person {
        var person = Person(id: id, name: name)
        person.popularity = popularity
        person.profilePicture = photo
        return person
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

    // MARK: - People strip order

    private func officeStub() -> StubProvider {
        var stub = StubProvider()
        var film = movie(1_358_005, "Office Romance", votes: 354, pop: 14.7)
        film.team = [person(1, "Jennifer Lopez", "Jackie Cruz"),
                     person(2, "Brett Goldstein", "Daniel Blanchflower")]
        stub.movieResults["office"] = [film]
        stub.movieDetailByID[1_358_005] = film

        var series = show(2_316, "The Office", votes: 5_382, pop: 110.4)
        series.recurringCast = [person(3, "Steve Carell", "Michael Scott"),
                                person(4, "Rainn Wilson", "Dwight Schrute")]
        stub.showResults["office"] = [series]
        stub.showDetails[2_316] = series
        return stub
    }

    @Test func theStripFollowsTheResultsWhenAShowWins() async {
        let result = await SearchPolicy.standard.run(query: "office", using: officeStub())
        #expect(result.results.first?.isMovie == false)
        // The show led the results, so its lead opens the strip — not the film's, which used
        // to come first purely because film cast was appended before show cast.
        #expect(result.castPeople.map(\.name) == ["Steve Carell", "Rainn Wilson",
                                                 "Jennifer Lopez", "Brett Goldstein"])
    }

    @Test func theStripFollowsTheResultsWhenAFilmWins() async {
        var stub = officeStub()
        var film = movie(414_906, "The Batman", votes: 12_324, pop: 31.9)
        film.team = [person(1, "Robert Pattinson", "Bruce Wayne"),
                     person(2, "Zoë Kravitz", "Selina Kyle")]
        stub.movieResults["batman"] = [film]
        stub.movieDetailByID[414_906] = film

        var series = show(15_804, "Batman", votes: 612, pop: 34.5)   // out-popularities the film
        series.recurringCast = [person(3, "Adam West", "Batman"),
                                person(4, "Burt Ward", "Robin")]
        stub.showResults["batman"] = [series]
        stub.showDetails[15_804] = series

        let result = await SearchPolicy.standard.run(query: "batman", using: stub)
        #expect(result.results.first?.isMovie == true)
        #expect(result.castPeople.map(\.name) == ["Robert Pattinson", "Zoë Kravitz",
                                                 "Adam West", "Burt Ward"])
    }

    @Test func theGuaranteedLeadsComeFromTheFilmTheListLeadsWith() async {
        var stub = StubProvider()
        var begins = movie(272, "Batman Begins", votes: 22_896, pop: 30, collectionID: 263)
        begins.team = [person(11, "Christian Bale", "Bruce Wayne / Batman"),
                       person(16, "Michael Caine", "Alfred")]
        var exact = movie(414_906, "The Batman", votes: 12_324, pop: 32)
        exact.team = [person(10, "Robert Pattinson", "Bruce Wayne / The Batman"),
                      person(14, "Zoë Kravitz", "Selina Kyle")]
        // The Dark Knight leads the list on votes, arriving via the collection — its title
        // shares no word with the query, so it is never a "named" film.
        var darkKnight = movie(155, "The Dark Knight", votes: 32_000, pop: 90)
        darkKnight.team = [person(11, "Christian Bale", "Bruce Wayne / Batman"),
                           person(15, "Heath Ledger", "Joker")]
        stub.movieResults["batman"] = [begins, exact]
        stub.movieDetailByID[272] = begins
        stub.movieDetailByID[414_906] = exact
        stub.movieDetailByID[155] = darkKnight
        stub.collectionParts[263] = [darkKnight, begins]

        let result = await SearchPolicy.standard.run(query: "batman", using: stub)
        #expect(result.results.first?.title == "The Dark Knight")
        // Characters first by film notability, then the list leader's other cast: Ledger ahead
        // of Caine and Kravitz, because The Dark Knight is what the list opens on.
        #expect(result.castPeople.map(\.name).prefix(3)
                == ["Christian Bale", "Robert Pattinson", "Heath Ledger"])
    }

    // MARK: - Name queries

    private func strip(query: String, using stub: StubProvider,
                       titleOwnsQuery: Bool = false) async -> [String] {
        let result = await SearchPolicy.standard.run(query: query, using: stub)
        return SearchMatching.featuredPeople(castMatched: result.castPeople,
                                             named: result.namedPeople,
                                             cap: 12, namedNoiseFloor: 1, query: query,
                                             titleOwnsQuery: titleOwnsQuery)
            .map(\.name)
    }

    @Test func aFirstNameLeadsWithThePeopleWhoBearIt() async {
        var stub = StubProvider()
        stub.peopleResults["robert"] = [
            namedPerson(1, "Robert Pattinson", popularity: 10.9),
            namedPerson(2, "Robert Downey Jr.", popularity: 11.5),
            namedPerson(3, "Robert Patrick", popularity: 6.9),
        ]
        // The 8-vote 1950s anthology that used to fill all eight visible slots.
        var anthology = show(2_120, "Robert Montgomery Presents", votes: 8, pop: 12)
        anthology.recurringCast = [person(90, "Robert Montgomery", "Self - Host"),
                                   person(91, "John Newland", "Harold Newcombe")]
        stub.showResults["robert"] = [anthology]
        stub.showDetails[2_120] = anthology

        let strip = await strip(query: "robert", using: stub)
        #expect(strip.prefix(3) == ["Robert Downey Jr.", "Robert Pattinson", "Robert Patrick"])
        // The anthology is too obscure to speak for the search at all.
        #expect(!strip.contains("John Newland"))
    }

    @Test func anObscureShowContributesNobodyHoweverPopular() async {
        var stub = StubProvider()
        var anthology = show(2_120, "Robert Montgomery Presents", votes: 8, pop: 44)
        anthology.recurringCast = [person(90, "Robert Montgomery", "Self - Host")]
        stub.showResults["robert"] = [anthology]
        stub.showDetails[2_120] = anthology

        let result = await SearchPolicy.standard.run(query: "robert", using: stub)
        #expect(result.castPeople.isEmpty)
    }

    @Test func namesakeNoiseDoesNotOutrankTheCast() async {
        var stub = StubProvider()
        var series = show(1_668, "Friends", votes: 9_293, pop: 60)
        series.recurringCast = [person(50, "Jennifer Aniston", "Rachel Green"),
                                person(51, "Courteney Cox", "Monica Geller")]
        stub.showResults["friends"] = [series]
        stub.showDetails[1_668] = series
        // Photos keep them credible enough to list, but not to lead.
        stub.peopleResults["friends"] = [
            namedPerson(1, "Line Friends", popularity: 0.25, photo: "/a.jpg"),
            namedPerson(2, "Ross From Friends", popularity: 0.4, photo: "/b.jpg"),
        ]

        let strip = await strip(query: "friends", using: stub, titleOwnsQuery: true)
        #expect(strip.prefix(2) == ["Jennifer Aniston", "Courteney Cox"])
    }

    @Test func charlizeFindsCharlizeTheron() async {
        var stub = StubProvider()
        stub.peopleResults["charlize"] = [namedPerson(1, "Charlize Theron", popularity: 9.4)]
        #expect(await strip(query: "charlize", using: stub) == ["Charlize Theron"])
    }

    @Test func scarlettFindsScarlettJohansson() async {
        var stub = StubProvider()
        stub.peopleResults["scarlett"] = [namedPerson(1, "Scarlett Johansson", popularity: 14.2)]
        #expect(await strip(query: "scarlett", using: stub) == ["Scarlett Johansson"])
    }

    @Test func aTitleHoldsItsQueryAgainstASingleNamesake() async {
        var stub = StubProvider()
        var film = movie(438_631, "Dune", votes: 11_000, pop: 60)
        film.team = [person(50, "Timothée Chalamet", "Paul Atreides"),
                     person(51, "Rebecca Ferguson", "Lady Jessica")]
        stub.movieResults["dune"] = [film]
        stub.movieDetailByID[438_631] = film
        stub.peopleResults["dune"] = [namedPerson(1, "Dune Streeter", popularity: 1.2)]

        let strip = await strip(query: "dune", using: stub, titleOwnsQuery: true)
        #expect(strip.prefix(2) == ["Timothée Chalamet", "Rebecca Ferguson"])
        #expect(strip.contains("Dune Streeter"))
    }

    @Test func aNameThatCollidesWithAFilmTitleKeepsBoth() async {
        var stub = StubProvider()
        var film = movie(11_252, "Carrie", votes: 5_000, pop: 40)
        film.team = [person(50, "Sissy Spacek", "Carrie White"),
                     person(51, "Piper Laurie", "Margaret White")]
        stub.movieResults["carrie"] = [film]
        stub.movieDetailByID[11_252] = film
        stub.peopleResults["carrie"] = [
            namedPerson(1, "Carrie Fisher", popularity: 12.0),
            namedPerson(2, "Carrie-Anne Moss", popularity: 8.5),
        ]

        let strip = await strip(query: "carrie", using: stub, titleOwnsQuery: true)
        #expect(strip.prefix(2) == ["Carrie Fisher", "Carrie-Anne Moss"])
        #expect(strip.contains("Sissy Spacek"))   // the film still contributes
    }

    @Test func aTitleNameFillsTheStripFromEveryFilmItNames() async {
        var stub = StubProvider()
        var first = movie(24, "The Avengers", votes: 39_244, pop: 77.5)
        first.team = [person(1, "Robert Downey Jr.", "Tony Stark"),
                      person(2, "Chris Evans", "Steve Rogers"),
                      person(3, "Mark Ruffalo", "Bruce Banner")]
        var sequel = movie(299_534, "Avengers: Endgame", votes: 28_328, pop: 63.7)
        sequel.team = [person(1, "Robert Downey Jr.", "Tony Stark"),
                       person(4, "Chris Hemsworth", "Thor")]
        stub.movieResults["avengers"] = [first, sequel]
        stub.movieDetailByID[24] = first
        stub.movieDetailByID[299_534] = sequel

        let result = await SearchPolicy.standard.run(query: "avengers", using: stub)
        // Top hit's leads first, then its remaining billing, then the sequel's new faces —
        // deduped, so Downey Jr. isn't listed twice.
        #expect(result.castPeople.map(\.name) == ["Robert Downey Jr.", "Chris Evans",
                                                 "Mark Ruffalo", "Chris Hemsworth"])
    }
}

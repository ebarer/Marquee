//
//  SearchMatchingTests.swift
//  MarqueeTests
//
//  Exercises the network-free search matching/ranking rules against synthetic
//  data. These guard the behaviour we tuned against live TMDB (character vs
//  name matching, spacing workaround, notability ordering, lead fallback) so a
//  regression surfaces here rather than only in the running app.
//

import Testing
import Foundation
@testable import Marquee

@Suite struct SearchMatchingTests {

    // MARK: - Helpers

    private func castMember(_ id: Int, _ name: String, _ character: String) -> Person {
        Person(id: id, name: name, role: character, pic: nil, type: .Cast)
    }

    private func namedPerson(_ id: Int, _ name: String, popularity: Float) -> Person {
        var p = Person(id: id, name: name)
        p.popularity = popularity
        return p
    }

    private func film(_ id: Int, _ title: String, votes: Int? = nil, popularity: Double? = nil,
                      cast: [Person]) -> (movie: Movie, cast: [Person]) {
        var m = Movie(id: id, title: title)
        m.voteCount = votes
        m.popularity = popularity
        return (m, cast)
    }

    // MARK: - normalized

    @Test func normalizedStripsPunctuationAndCase() {
        #expect(SearchMatching.normalized("Spider-Man") == "spiderman")
        #expect(SearchMatching.normalized("Tony Stark / Iron Man") == "tonystarkironman")
        #expect(SearchMatching.normalized("  Batman!  ") == "batman")
    }

    // MARK: - heroSegments

    @Test func heroSegmentsMatchesTitleRoleNotBitPart() {
        #expect(SearchMatching.heroSegments(of: "Peter Parker / Spider-Man").contains("spiderman"))
        #expect(SearchMatching.heroSegments(of: "Spider-Man / Peter Parker").contains("spiderman"))
        // A descriptive bit-part must not reduce to the hero name.
        #expect(!SearchMatching.heroSegments(of: "Yeah Spider-Man Guy").contains("spiderman"))
    }

    @Test func heroSegmentsStripsArticleAndParentheticals() {
        #expect(SearchMatching.heroSegments(of: "Bruce Wayne / The Batman").contains("batman"))
        #expect(SearchMatching.heroSegments(of: "Batman (Bruce Wayne)").contains("batman"))
        #expect(SearchMatching.heroSegments(of: "Batman / Bruce Wayne (voice)").contains("batman"))
        // "Superman Robot #12 (voice)" is not the hero.
        #expect(!SearchMatching.heroSegments(of: "Superman Robot #12 (voice)").contains("superman"))
    }

    // MARK: - spacedVariant

    @Test func spacedVariantSplitsBeforeHeroSuffix() {
        #expect(SearchMatching.spacedVariant(of: "ironman") == "iron man")
        #expect(SearchMatching.spacedVariant(of: "antman") == "ant man")
        #expect(SearchMatching.spacedVariant(of: "catwoman") == "cat woman")  // "woman" beats "man"
        #expect(SearchMatching.spacedVariant(of: "batman") == "bat man")
    }

    @Test func spacedVariantReturnsNilWhenNotApplicable() {
        #expect(SearchMatching.spacedVariant(of: "iron man") == nil)  // already spaced
        #expect(SearchMatching.spacedVariant(of: "xman") == nil)      // prefix too short
        #expect(SearchMatching.spacedVariant(of: "inception") == nil) // no hero suffix
    }

    // MARK: - titleMatches

    @Test func titleMatchesArticleStrippedExactly() {
        #expect(SearchMatching.titleMatches("Iron Man", normalizedQuery: "ironman"))
        #expect(SearchMatching.titleMatches("The Matrix", normalizedQuery: "matrix"))
        #expect(!SearchMatching.titleMatches("Iron Man 2", normalizedQuery: "ironman"))
        #expect(!SearchMatching.titleMatches("Batman Begins", normalizedQuery: "batman"))
    }

    // MARK: - moviePeople: character matches

    private func moviePeople(query: String,
                             _ films: [(movie: Movie, cast: [Person])]) -> [Person] {
        SearchMatching.moviePeople(query: query, films: films,
                                   minQueryLength: 4, topBilledPerFilm: 15,
                                   leadFallbackCount: 1, leadFallbackMinPopularity: 10)
    }

    @Test func characterMatchesOrderByFilmVoteCount() {
        // Pattinson's film is passed first, but Bale's has more lifetime votes.
        let films = [
            film(1, "The Batman", votes: 12_241, cast: [castMember(10, "Robert Pattinson", "Bruce Wayne / The Batman")]),
            film(2, "Batman Begins", votes: 22_896, cast: [castMember(11, "Christian Bale", "Bruce Wayne / Batman")]),
        ]
        #expect(moviePeople(query: "batman", films).map(\.name) == ["Christian Bale", "Robert Pattinson"])
    }

    @Test func characterMatchesDedupeAcrossFilms() {
        let holland = castMember(20, "Tom Holland", "Peter Parker / Spider-Man")
        let films = [
            film(1, "Spider-Man: No Way Home", votes: 19_000, cast: [holland]),
            film(2, "Spider-Man: Homecoming", votes: 21_000, cast: [holland]),
        ]
        let result = moviePeople(query: "spiderman", films)
        #expect(result.map(\.name) == ["Tom Holland"])
    }

    @Test func characterMatchesExcludeBitParts() {
        let films = [
            film(1, "Spider-Man: Homecoming", votes: 21_000, cast: [
                castMember(20, "Tom Holland", "Peter Parker / Spider-Man"),
                castMember(58, "Omar Capra", "Yeah Spider-Man Guy"),
            ]),
        ]
        #expect(moviePeople(query: "spiderman", films).map(\.name) == ["Tom Holland"])
    }

    @Test func shortQueryYieldsNoCharacterMatches() {
        let films = [film(1, "Batman", votes: 100, cast: [castMember(1, "X", "Batman")])]
        #expect(moviePeople(query: "bat", films).isEmpty)  // below minQueryLength
    }

    // MARK: - moviePeople: lead fallback

    @Test func leadFallbackSurfacesStarWhenNoCharacterMatch() {
        // RDJ is credited "Tony Stark", never "Iron Man" — so no character match.
        let films = [
            film(1, "Iron Man", votes: 25_000, popularity: 48, cast: [
                castMember(30, "Robert Downey Jr.", "Tony Stark"),
                castMember(31, "Terrence Howard", "Rhodey"),
            ]),
        ]
        // leadFallbackCount is 1, so only the star (not Rhodey) surfaces.
        #expect(moviePeople(query: "ironman", films).map(\.name) == ["Robert Downey Jr."])
    }

    @Test func leadFallbackRequiresNotableFilmNamedByQuery() {
        let cast = [castMember(30, "Robert Downey Jr.", "Tony Stark")]
        // Too obscure (popularity below threshold).
        #expect(moviePeople(query: "ironman", [film(1, "Iron Man", popularity: 3, cast: cast)]).isEmpty)
        // Title doesn't equal the query, so we don't guess a lead.
        #expect(moviePeople(query: "ironman", [film(1, "Iron Man 2", popularity: 40, cast: cast)]).isEmpty)
    }

    // MARK: - featuredPeople

    @Test func featuredPeoplePutsMovieMatchesFirstThenNamedByPopularity() {
        let bale = castMember(11, "Christian Bale", "Batman")
        let named = [namedPerson(50, "Low", popularity: 5), namedPerson(51, "High", popularity: 10)]
        let result = SearchMatching.featuredPeople(movieMatched: [bale], named: named, cap: 12)
        #expect(result.map(\.name) == ["Christian Bale", "High", "Low"])
    }

    @Test func featuredPeopleDedupesAndCaps() {
        let shared = namedPerson(11, "Christian Bale", popularity: 8)
        let movieMatched = [castMember(11, "Christian Bale", "Batman")]  // same id as `shared`
        let named = [shared, namedPerson(52, "Other", popularity: 9)]
        let result = SearchMatching.featuredPeople(movieMatched: movieMatched, named: named, cap: 12)
        #expect(result.map(\.id) == [11, 52])  // Bale not duplicated

        let capped = SearchMatching.featuredPeople(
            movieMatched: movieMatched,
            named: (0..<20).map { namedPerson(100 + $0, "P\($0)", popularity: Float($0)) },
            cap: 5)
        #expect(capped.count == 5)
    }

    @Test func featuredPeopleDropsNoiseEntriesWithoutPhotoOrPopularity() {
        func withPhoto(_ p: Person) -> Person { var q = p; q.profilePicture = "/x.jpg"; return q }

        let junk = namedPerson(60, "Toy Story Alien", popularity: 0.13)           // no photo, low pop
        let obscureReal = withPhoto(namedPerson(61, "Obscure Actor", popularity: 0.2)) // photo saves it
        let popularNoPhoto = namedPerson(62, "Popular", popularity: 5)            // pop saves it

        let result = SearchMatching.featuredPeople(
            movieMatched: [], named: [junk, obscureReal, popularNoPhoto],
            cap: 12, namedNoiseFloor: 1)
        #expect(result.map(\.name) == ["Popular", "Obscure Actor"])  // junk dropped
    }
}

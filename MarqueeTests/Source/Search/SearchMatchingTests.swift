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
        var person = Person(id: id, name: name)
        person.popularity = popularity
        return person
    }

    private func film(_ id: Int, _ title: String, votes: Int? = nil, popularity: Double? = nil,
                      cast: [Person]) -> (movie: Movie, cast: [Person]) {
        var movie = Movie(id: id, title: title)
        movie.voteCount = votes
        movie.popularity = popularity
        return (movie, cast)
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

    // MARK: - shouldTryAnchorRecovery

    @Test func anchorRecoveryFiresWhenRelatedToAnchor() {
        // Extending the anchor forward ("bad" → "bad boy", "iron" → "ironm")…
        #expect(SearchMatching.shouldTryAnchorRecovery(query: "bad boy", lastStrongQuery: "bad", minLength: 4))
        #expect(SearchMatching.shouldTryAnchorRecovery(query: "ironm", lastStrongQuery: "iron", minLength: 4))
        // …or backspacing within it ("ironman" → "ironma").
        #expect(SearchMatching.shouldTryAnchorRecovery(query: "ironma", lastStrongQuery: "ironman", minLength: 4))
    }

    @Test func anchorRecoveryDoesNotFireWhenUnrelatedOrTiny() {
        #expect(!SearchMatching.shouldTryAnchorRecovery(query: "batma", lastStrongQuery: "ironman", minLength: 4)) // unrelated
        #expect(!SearchMatching.shouldTryAnchorRecovery(query: "iro", lastStrongQuery: "ironman", minLength: 4))   // below stem
        #expect(!SearchMatching.shouldTryAnchorRecovery(query: "iron", lastStrongQuery: "iron", minLength: 4))     // equal
        #expect(!SearchMatching.shouldTryAnchorRecovery(query: "ironm", lastStrongQuery: "", minLength: 4))        // no anchor
    }

    // MARK: - articleStripped

    @Test func articleStrippedRemovesLeadingArticle() {
        #expect(SearchMatching.articleStripped("The Matrix") == "matrix")
        #expect(SearchMatching.articleStripped("A Bug's Life") == "bug's life")
        #expect(SearchMatching.articleStripped("An American Tail") == "american tail")
        #expect(SearchMatching.articleStripped("Amadeus") == "amadeus")  // "a" not a standalone article
    }

    // MARK: - interpunctVariant

    @Test func interpunctVariantConvertsSeparatorsToBullet() {
        #expect(SearchMatching.interpunctVariant(of: "wall e") == "wall·e")
        #expect(SearchMatching.interpunctVariant(of: "wall-e") == "wall·e")
        #expect(SearchMatching.interpunctVariant(of: "wall - e") == "wall·e")   // collapses a run
        #expect(SearchMatching.interpunctVariant(of: "spider man") == "spider·man")
    }

    @Test func interpunctVariantNilWithoutSeparator() {
        #expect(SearchMatching.interpunctVariant(of: "walle") == nil)   // nothing to convert
        #expect(SearchMatching.interpunctVariant(of: "batman") == nil)
        #expect(SearchMatching.interpunctVariant(of: "wall·e") == nil)  // already a bullet
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
        #expect(SearchMatching.titleMatches("A Bug's Life", normalizedQuery: "bugslife"))  // "a" stripped
        #expect(!SearchMatching.titleMatches("Iron Man 2", normalizedQuery: "ironman"))
        #expect(!SearchMatching.titleMatches("Batman Begins", normalizedQuery: "batman"))
    }

    // MARK: - moviePeople: character matches

    private func moviePeople(query: String,
                             _ films: [(movie: Movie, cast: [Person])]) -> [Person] {
        SearchMatching.moviePeople(query: query, films: films,
                                   minQueryLength: 4, leadPrefixMinLength: 3,
                                   topBilledPerFilm: 15,
                                   minCharacterMatchVotes: 100,
                                   leadFallbackCount: 2, leadFallbackMinPopularity: 10)
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

    @Test func obscureFilmCharacterMatchIsIgnoredForFallbackStar() {
        // The "Troy" bug: a no-name film credits a character named "Troy", surfacing an
        // unknown ahead of the star. The notability floor drops that cast, so the lead wins.
        let films = [
            film(652, "Troy", votes: 11_312, popularity: 64, cast: [
                castMember(287, "Brad Pitt", "Achilles"),
            ]),
            film(967_252, "Troy", votes: 6, cast: [
                castMember(9_999, "Random Unknown", "Troy"),
            ]),
        ]
        #expect(moviePeople(query: "troy", films).map(\.name) == ["Brad Pitt"])
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
        // leadFallbackCount is 2, so both leads surface (star + co-lead).
        #expect(moviePeople(query: "ironman", films).map(\.name) == ["Robert Downey Jr.", "Terrence Howard"])
    }

    @Test func leadFallbackSurfacesStarForShortExactTitle() {
        // "300" is below minQueryLength so no character match runs, but the lead
        // fallback is exact-title + popularity gated, so it still surfaces the leads.
        let films = [
            film(1271, "300", votes: 14_928, popularity: 16, cast: [
                castMember(1, "Gerard Butler", "King Leonidas"),
                castMember(2, "Lena Headey", "Gorgo"),
            ]),
        ]
        #expect(moviePeople(query: "300", films).map(\.name) == ["Gerard Butler", "Lena Headey"])
    }

    @Test func leadFallbackRequiresNotableFilmNamedByQuery() {
        let cast = [castMember(30, "Robert Downey Jr.", "Tony Stark")]
        // Too obscure (popularity below threshold).
        #expect(moviePeople(query: "ironman", [film(1, "Iron Man", popularity: 3, cast: cast)]).isEmpty)
        // Title isn't the query nor a prefix of it, so we don't guess a lead.
        #expect(moviePeople(query: "ironman", [film(1, "The Avengers", popularity: 40, cast: cast)]).isEmpty)
    }

    @Test func leadFallbackAllowsSequelPrefix() {
        // A prefix spanning into a sequel is fine — the top hit is the film the
        // user means, and the sequel usually shares the lead.
        let cast = [castMember(30, "Robert Downey Jr.", "Tony Stark")]
        #expect(moviePeople(query: "ironman", [film(1, "Iron Man 2", popularity: 40, cast: cast)]).map(\.name) == ["Robert Downey Jr."])
    }

    @Test func leadFallbackSurfacesLeadsForTitlePrefix() {
        // Typing a prefix of the top film's title still surfaces its leads, so
        // "odysse" suggests The Odyssey's cast before the full title is typed.
        let films = [
            film(1, "The Odyssey", votes: 500, popularity: 40, cast: [
                castMember(10, "Matt Damon", "Odysseus"),
                castMember(11, "Tom Holland", "Telemachus"),
            ]),
        ]
        #expect(moviePeople(query: "odysse", films).map(\.name) == ["Matt Damon", "Tom Holland"])
    }

    @Test func leadFallbackHandlesArticleAndApostropheTitle() {
        // "bug's" (normalized "bugs") is a prefix of "A Bug's Life" once the "a"
        // article is stripped, so its leads surface without typing the article.
        let films = [
            film(1, "A Bug's Life", votes: 5_000, popularity: 40, cast: [
                castMember(10, "Dave Foley", "Flik"),
                castMember(11, "Kevin Spacey", "Hopper"),
            ]),
        ]
        #expect(moviePeople(query: "bug's", films).map(\.name) == ["Dave Foley", "Kevin Spacey"])
    }

    @Test func leadFallbackSurfacesLeadsForThreeCharTitlePrefix() {
        // A 3-char prefix ("ody") still surfaces the top film's leads — the lead
        // fallback floor is lower than the character-match floor (4).
        let films = [
            film(1, "The Odyssey", votes: 500, popularity: 40, cast: [
                castMember(10, "Matt Damon", "Odysseus"),
                castMember(11, "Tom Holland", "Telemachus"),
            ]),
        ]
        #expect(moviePeople(query: "ody", films).map(\.name) == ["Matt Damon", "Tom Holland"])
    }

    @Test func topFilmLeadsApplyExactAnyLengthOrPrefixAboveFloor() {
        // Exact title matches at any length.
        #expect(SearchMatching.topFilmLeadsApply(topTitle: "300", normalizedQuery: "300", minQueryLength: 4))
        #expect(SearchMatching.topFilmLeadsApply(topTitle: "Up", normalizedQuery: "up", minQueryLength: 4))
        // Prefix matches once it clears the length floor (article stripped).
        #expect(SearchMatching.topFilmLeadsApply(topTitle: "The Odyssey", normalizedQuery: "odysse", minQueryLength: 4))
        // Prefix below the floor is rejected (avoids churn on 1–2 char fragments).
        #expect(!SearchMatching.topFilmLeadsApply(topTitle: "The Odyssey", normalizedQuery: "od", minQueryLength: 4))
        // A prefix spanning into a sequel is allowed (top hit is the meant film).
        #expect(SearchMatching.topFilmLeadsApply(topTitle: "Iron Man 2", normalizedQuery: "ironman", minQueryLength: 4))
        // A query that isn't a prefix of the title doesn't match.
        #expect(!SearchMatching.topFilmLeadsApply(topTitle: "The Avengers", normalizedQuery: "ironman", minQueryLength: 4))
    }

    // MARK: - rankedForDisplay

    @Test func rankedForDisplaySortsNotableByPopularityThenSinksLowVote() {
        let movies = [
            film(1, "Old Classic", votes: 13_000, popularity: 21, cast: []).movie,   // many votes, cold
            film(2, "Trending New", votes: 2_000, popularity: 944, cast: []).movie,  // fewer votes, hot
            film(3, "Junk", votes: 6, popularity: 999, cast: []).movie,              // popularity spike, sub-floor
            film(4, "At Floor", votes: 100, popularity: 5, cast: []).movie,
        ]
        let result = SearchMatching.rankedForDisplay(movies, minVotes: 100)
        // Notable bucket ordered by popularity (Trending over Old Classic despite
        // fewer votes); the 6-vote Junk stays sunk regardless of its popularity.
        #expect(result.map(\.title) == ["Trending New", "Old Classic", "At Floor", "Junk"])
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

    // MARK: - inlinePeopleCount

    private func inlineCount(movieMatched: [Person], named: [Person]) -> Int {
        func withPhoto(_ person: Person) -> Person {
            var photographed = person
            photographed.profilePicture = "/x.jpg"
            return photographed
        }
        let featured = SearchMatching.featuredPeople(
            movieMatched: movieMatched,
            named: named.map(withPhoto),  // photos so the noise filter keeps them
            cap: 50, namedNoiseFloor: 1)
        return SearchMatching.inlinePeopleCount(
            featured, movieMatchedIDs: Set(movieMatched.map(\.id)),
            inlinePopularityFloor: 1, minInline: 3, previewLimit: 8)
    }

    @Test func inlineFoldsLowPopularityNamesakesBehindMovieMatches() {
        // The "Up" case: 2 movie leads + 5 obscure namesakes (pop < 1) → only the
        // 2 leads inline, the rest fold under "More", even though total is < 8.
        let leads = [castMember(1, "Ed Asner", "Carl"), castMember(2, "Christopher Plummer", "Muntz")]
        let namesakes = (0..<5).map { namedPerson(100 + $0, "Namesake \($0)", popularity: 0.2) }
        #expect(inlineCount(movieMatched: leads, named: namesakes) == 2)
    }

    @Test func inlineKeepsPopularNamedPeople() {
        // A name search: popular namesakes clear the floor and stay inline.
        let named = [namedPerson(1, "Famous", popularity: 30),
                     namedPerson(2, "Known", popularity: 4),
                     namedPerson(3, "Obscure", popularity: 0.1)]
        #expect(inlineCount(movieMatched: [], named: named) == 2)  // Obscure folds
    }

    @Test func inlineShowsMinimumWhenNothingIsProminent() {
        // Pure obscure-name search: nothing clears the bar, so show the top few
        // rather than a bare "More" button.
        let named = (0..<6).map { namedPerson(1 + $0, "Obscure \($0)", popularity: 0.1) }
        #expect(inlineCount(movieMatched: [], named: named) == 3)  // minInline
    }

    @Test func inlineFoldsPhotolessNamesakeAbovePopularityFloor() {
        // The "300" case: a photoless junk entry ("AI-D*300", pop just over the
        // floor) folds under More, while the photographed real person stays inline.
        func withPhoto(_ person: Person) -> Person {
            var photographed = person
            photographed.profilePicture = "/x.jpg"
            return photographed
        }
        let leads = [castMember(1, "Gerard Butler", "Leonidas"), castMember(2, "Lena Headey", "Gorgo")]
        let andre = withPhoto(namedPerson(10, "André 3000", popularity: 1.44)) // photo → prominent
        let junk = namedPerson(11, "AI-D*300", popularity: 1.04)               // no photo → folds
        let featured = SearchMatching.featuredPeople(movieMatched: leads, named: [andre, junk],
                                                     cap: 50, namedNoiseFloor: 1)
        #expect(featured.map(\.name).contains("AI-D*300"))  // still reachable in the full list
        let inline = SearchMatching.inlinePeopleCount(
            featured, movieMatchedIDs: Set(leads.map(\.id)),
            inlinePopularityFloor: 1, minInline: 3, previewLimit: 8)
        #expect(inline == 3)  // Butler, Headey, André 3000 — junk folded
    }

    @Test func inlineClampsToPreviewLimit() {
        let many = (0..<20).map { castMember(1 + $0, "Cast \($0)", "Role \($0)") }
        #expect(inlineCount(movieMatched: many, named: []) == 8)  // previewLimit
    }

    @Test func featuredPeopleDropsNoiseEntriesWithoutPhotoOrPopularity() {
        func withPhoto(_ person: Person) -> Person {
            var photographed = person
            photographed.profilePicture = "/x.jpg"
            return photographed
        }

        let junk = namedPerson(60, "Toy Story Alien", popularity: 0.13)           // no photo, low pop
        let obscureReal = withPhoto(namedPerson(61, "Obscure Actor", popularity: 0.2)) // photo saves it
        let popularNoPhoto = namedPerson(62, "Popular", popularity: 5)            // pop saves it

        let result = SearchMatching.featuredPeople(
            movieMatched: [], named: [junk, obscureReal, popularNoPhoto],
            cap: 12, namedNoiseFloor: 1)
        #expect(result.map(\.name) == ["Popular", "Obscure Actor"])  // junk dropped
    }
}

//
//  Person+KnownForTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct PersonKnownForTests {
    private func film(_ id: Int, votes: Int, order: Int? = 0, poster: String? = "/p.jpg",
                      role: String? = nil, released: Date? = nil) -> Movie {
        var movie = Movie(id: id, title: "M\(id)")
        movie.voteCount = votes
        movie.creditOrder = order
        movie.poster = poster
        movie.creditRole = role
        movie.releaseDate = released
        return movie
    }

    private func series(_ id: Int, votes: Int, episodes: Int, aired: Date? = nil) -> Show {
        var show = Show(id: id, name: "S\(id)")
        show.voteCount = votes
        show.episodeCount = episodes
        show.poster = "/p.jpg"
        show.firstAirDate = aired
        return show
    }

    @Test func excludesExtraneousAndPosterlessCredits() {
        var person = Person(id: 1, name: "A")
        person.credits = [
            film(1, votes: 100),
            film(2, votes: 9_000, poster: nil),
            film(3, votes: 9_000, role: "Self"),
        ]
        #expect(person.knownFor.map(\.id) == ["movie-1"])
    }

    @Test func emptyWhenNoCredits() {
        #expect(Person(id: 1, name: "A").knownFor.isEmpty)
    }

    @Test func leadRoleOutranksBitPartInABiggerTitle() {
        var person = Person(id: 1, name: "A")
        person.credits = [film(1, votes: 20_000, order: 12), film(2, votes: 3_000, order: 0)]
        #expect(person.knownFor.map(\.id) == ["movie-2", "movie-1"])
    }

    @Test func topBilledCreditsAreWeightedEqually() {
        // TMDB's ordering within the principal cast isn't meaningful, so votes decide.
        var person = Person(id: 1, name: "A")
        person.credits = [film(1, votes: 3_000, order: 5), film(2, votes: 4_000, order: 0)]
        #expect(person.knownFor.map(\.id) == ["movie-2", "movie-1"])
    }

    @Test func seriesRegularOutranksAGuestSpotAndABitPart() {
        // TMDB votes skew heavily to film, so a long-running role has to survive on more
        // than raw vote count — a 254-episode lead over a one-episode cameo.
        var person = Person(id: 1, name: "A")
        person.credits = [film(1, votes: 13_000, order: 8)]
        person.tvCredits = [series(9, votes: 900, episodes: 254), series(8, votes: 11_000, episodes: 1)]
        #expect(person.knownFor.map(\.id) == ["show-9", "movie-1", "show-8"])
    }

    @Test func recentWorkEdgesOutAnEquallyVotedOlderCredit() {
        let now = Date()
        let lastYear = Calendar.current.date(byAdding: .month, value: -12, to: now)!
        let longAgo = Calendar.current.date(byAdding: .year, value: -20, to: now)!
        var person = Person(id: 1, name: "A")
        person.credits = [film(1, votes: 1_000, released: longAgo),
                          film(2, votes: 1_000, released: lastYear)]
        #expect(person.knownFor.map(\.id) == ["movie-2", "movie-1"])
    }
}

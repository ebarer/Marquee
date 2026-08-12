//
//  PersonTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct PersonTests {
    @Test func identityIsTMDBID() {
        let a = Person(id: 5, name: "A")
        let b = Person(id: 5, name: "B")
        #expect(a == b)
    }

    @Test func knownForExcludesExtraneousAndPosterlessSortedByPopularity() {
        func credit(_ id: Int, poster: String?, pop: Double, role: String? = nil) -> Movie {
            var m = Movie(id: id, title: "M\(id)")
            m.poster = poster; m.popularity = pop; m.creditRole = role
            return m
        }
        var p = Person(id: 1, name: "A")
        p.credits = [
            credit(1, poster: "/a.jpg", pop: 10),
            credit(2, poster: nil, pop: 99),                 // no poster -> excluded
            credit(3, poster: "/c.jpg", pop: 50, role: "Self"), // extraneous -> excluded
            credit(4, poster: "/d.jpg", pop: 30),
        ]
        #expect(p.knownFor.map(\.id) == [4, 1])
    }

    @Test func knownForEmptyWhenNoCredits() {
        #expect(Person(id: 1, name: "A").knownFor.isEmpty)
    }

    @Test func profileURL() {
        var p = Person(id: 1, name: "A")
        #expect(p.profileURL() == nil)
        p.profilePicture = "/pic.jpg"
        #expect(p.profileURL(.orig)?.absoluteString == "https://image.tmdb.org/t/p/original//pic.jpg")
    }
}

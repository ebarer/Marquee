//
//  PersonTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct PersonTests {
    @Test func identityIsTMDBID() {
        let first = Person(id: 5, name: "A")
        let second = Person(id: 5, name: "B")
        #expect(first == second)
    }

    @Test func profileURL() {
        var person = Person(id: 1, name: "A")
        #expect(person.profileURL() == nil)
        person.profilePicture = "/pic.jpg"
        #expect(person.profileURL(.orig)?.absoluteString == "https://image.tmdb.org/t/p/original//pic.jpg")
    }
}

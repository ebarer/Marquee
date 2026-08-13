//
//  StringExtensionTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftUI
@testable import Marquee

@Suite struct StringExtensionTests {
    @Test func shortenKnownGenres() {
        #expect("Science Fiction".shorten() == "Sci-Fi")
        #expect("Documentary".shorten() == "Docu.")
        #expect("Action".shorten() == "Action")
    }

    @Test func toDateParsesISOFormats() {
        let day = "2007-07-19".toDate(format: .iso8601DAw)
        #expect(day == Date.utc(2007, 7, 19))
        let dateTime = "2020-05-01T12:30:00.000+00:00".toDate(format: .iso8601DTw)
        #expect(dateTime != nil)
    }

    @Test func toDateReturnsNilForGarbage() {
        #expect("not-a-date".toDate(format: .iso8601DAw) == nil)
    }
}

//
//  DateFormatterTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftUI
@testable import Marquee

@Suite struct DateFormatterTests {
    @Test func detailPresentation() {
        #expect(Date.utc(2021, 3, 9).toString() == "Mar 9, 2021")
    }

    @Test func sectionHeaderIsMonthYear() {
        #expect(DateFormatter.sectionHeader.string(from: .utc(2025, 5, 15)) == "May 2025")
    }

    @Test func roundTripDayFormatter() {
        let s = "1994-12-25"
        #expect(DateFormatter.iso8601DAw.date(from: s).map { DateFormatter.iso8601DAw.string(from: $0) } == s)
    }
}

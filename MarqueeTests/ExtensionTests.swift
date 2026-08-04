//
//  ExtensionTests.swift
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

@Suite struct ColorExtensionTests {
    @Test func hexParsesWithAndWithoutHash() {
        #expect(Color(hex: "#FF8800") != nil)
        #expect(Color(hex: "ff8800") != nil)
        #expect(Color(hex: "  #FFFFFF  ") != nil)
    }

    @Test func hexRejectsMalformed() {
        #expect(Color(hex: "FFF") == nil)
        #expect(Color(hex: "GGGGGG") == nil)
        #expect(Color(hex: "#FF88000") == nil)
    }

    @Test func hexRoundTrip() {
        let hex = Color(hex: "#3A82F6")?.hexString
        #expect(hex == "#3A82F6")
    }

    @Test func listColorWrapsOutOfRange() {
        let count = Color.listPalette.count
        #expect(Color.listColor(0) == Color.listColor(count))
        #expect(Color.listColor(-1) == Color.listColor(count - 1))
    }

    @Test func whiteFadedClampsInvalidBrightness() {
        #expect(Color.whiteFaded(-1) == Color.whiteFaded())
        #expect(Color.whiteFaded(2) == Color.whiteFaded())
        #expect(Color.whiteFaded(0.5) == Color(red: 0.5, green: 0.5, blue: 0.5))
    }

    @Test func rgb255Initializer() {
        #expect(Color(red255: 255, green255: 0, blue255: 0).hexString == "#FF0000")
    }
}

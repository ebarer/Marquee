//
//  ColorExtensionTests.swift
//  MarqueeTests
//

import Testing
import Foundation
import SwiftUI
@testable import Marquee

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

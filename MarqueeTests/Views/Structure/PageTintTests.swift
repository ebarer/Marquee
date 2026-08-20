//
//  PageTintTests.swift
//  MarqueeTests
//

import Testing
import SwiftUI
@testable import Marquee

@Suite struct PageTintTests {
    private func reduce(_ initial: Color?, _ next: Color?) -> Color? {
        var value = initial
        PageTintKey.reduce(value: &value, nextValue: { next })
        return value
    }

    @Test func defaultIsNoTint() {
        #expect(PageTintKey.defaultValue == nil)
    }

    @Test func lastPublishedColourWins() {
        #expect(reduce(.green, .red) == .red)
    }

    // A pushed screen's tint has to survive the siblings around it that publish nothing,
    // or the tab bar flickers back to the accent as the stack re-renders.
    @Test func nilNeverErasesAColour() {
        #expect(reduce(.red, nil) == .red)
    }

    @Test func firstColourFillsAnEmptyValue() {
        #expect(reduce(nil, .red) == .red)
    }

    @Test func nothingPublishedStaysNil() {
        #expect(reduce(nil, nil) == nil)
    }

    @Test func frontmostPageWinsAcrossQuietSiblings() {
        var value: Color? = nil
        for next in [Color.green, nil, nil, Color.red, nil] {
            PageTintKey.reduce(value: &value, nextValue: { next })
        }
        #expect(value == .red)
    }
}

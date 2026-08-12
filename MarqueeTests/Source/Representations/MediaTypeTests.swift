//
//  MediaTypeTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

@Suite struct MediaTypeTests {
    @Test func rawValues() {
        #expect(MediaType.movie.rawValue == 0)
        #expect(MediaType.tv.rawValue == 1)
        #expect(MediaType(rawValue: 0) == .movie)
        #expect(MediaType(rawValue: 99) == nil)
    }
}

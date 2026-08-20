//
//  SectionStartTests.swift
//  MarqueeTests
//

import Testing
import Foundation
@testable import Marquee

/// The section a month-bucketed list opens on: last month, or the nearest month to it.
@Suite struct SectionStartTests {
    private func section(_ year: Int, _ month: Int) -> SectionSnapshot {
        SectionSnapshot(id: DateComponents(year: year, month: month),
                        title: "\(month)/\(year)", entries: [], isCollapsible: false)
    }

    private let now = Date.utc(2026, 8, 18)

    @Test func opensOnLastMonth() {
        let sections = [section(2026, 6), section(2026, 7), section(2026, 8), section(2026, 9)]

        let start = sections.monthSection(monthsBack: 1, from: now)

        #expect(start?.id == DateComponents(year: 2026, month: 7))
    }

    @Test func fallsBackToTheNearestMonth() {
        let sections = [section(2026, 4), section(2026, 9)]

        let start = sections.monthSection(monthsBack: 1, from: now)

        #expect(start?.id == DateComponents(year: 2026, month: 9))   // 2 months out vs. 3
    }

    @Test func aTieGoesToTheEarlierMonth() {
        let sections = [section(2026, 5), section(2026, 9)]

        let start = sections.monthSection(monthsBack: 1, from: now)

        #expect(start?.id == DateComponents(year: 2026, month: 5))
    }

    @Test func crossesTheYearBoundary() {
        let sections = [section(2025, 12), section(2026, 3)]

        let start = sections.monthSection(monthsBack: 1, from: Date.utc(2026, 1, 10))

        #expect(start?.id == DateComponents(year: 2025, month: 12))
    }

    @Test func ignoresSectionsWithoutAMonth() {
        let sections = [SectionSnapshot(id: SectionSnapshot.olderID, title: "Older",
                                        entries: [], isCollapsible: true),
                        SectionSnapshot(id: DateComponents(year: 9009), title: "4.5 Stars",
                                        entries: [], isCollapsible: false, ratingStars: 4.5)]

        #expect(sections.monthSection(monthsBack: 1, from: now) == nil)
        #expect([SectionSnapshot]().monthSection(monthsBack: 1, from: now) == nil)
    }
}

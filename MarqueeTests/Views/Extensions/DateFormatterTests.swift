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
        let day = "1994-12-25"
        #expect(DateFormatter.iso8601DAw.date(from: day)
            .map { DateFormatter.iso8601DAw.string(from: $0) } == day)
    }

    /// An air date `days` out, built the way TMDB's are: UTC midnight on a calendar day.
    private func airDate(inDays days: Int) -> Date {
        DateFormatter.utcCalendar
            .date(byAdding: .day, value: days, to: MediaItem.floatingDay(from: Date()))!
    }

    /// The air date is UTC midnight, which is the *previous* evening west of UTC — so an
    /// instant comparison calls tomorrow's episode aired once the local clock passes it.
    @Test(arguments: [0, 6, 12, 17, 20, 23])
    func tomorrowStaysInTheFutureAtEveryHourOfToday(hour: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let airDate = MediaItem.floatingDay(from: tomorrow)
        let now = Calendar.current.date(byAdding: .hour, value: hour, to: today)!

        #expect(airDate.isInTheFuture(asOf: now), "\(hour):00 local")
    }

    @Test(arguments: [0, 6, 12, 17, 20, 23])
    func todayHasArrivedAtEveryHourOfToday(hour: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        let airDate = MediaItem.floatingDay(from: today)
        let now = Calendar.current.date(byAdding: .hour, value: hour, to: today)!

        #expect(!airDate.isInTheFuture(asOf: now), "\(hour):00 local")
    }

    /// Shared by the episode controls and the Watch List's leading swipe, so both turn on at
    /// the same moment: local midnight on the air day.
    @Test func stopsBeingFutureAtLocalMidnight() {
        let calendar = Calendar.current
        let airDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let airDate = MediaItem.floatingDay(from: airDay)
        let midnight = calendar.startOfDay(for: airDay)

        #expect(airDate.isInTheFuture(asOf: midnight.addingTimeInterval(-1)))
        #expect(!airDate.isInTheFuture(asOf: midnight))
    }

    @Test func todayAndTomorrowAreNamed() {
        #expect(airDate(inDays: 0).toRelativeDayString() == "Today")
        #expect(airDate(inDays: 1).toRelativeDayString() == "Tomorrow")
    }

    @Test(arguments: [2, 3, 6]) func weekdayNameForTheRestOfTheWeek(days: Int) {
        let date = airDate(inDays: days)
        #expect(date.toRelativeDayString() == DateFormatter.weekdayName.string(from: date))
    }

    @Test(arguments: [7, 30, -1]) func fullDateOutsideTheComingWeek(days: Int) {
        let date = airDate(inDays: days)
        #expect(date.toRelativeDayString() == date.toString())
    }

    /// Drives the tinting, so it has to agree with which dates get named.
    @Test(arguments: [0, 1, 6]) func withinTheComingWeek(days: Int) {
        #expect(airDate(inDays: days).isWithinTheComingWeek)
    }

    @Test(arguments: [7, 30, -1]) func outsideTheComingWeek(days: Int) {
        #expect(!airDate(inDays: days).isWithinTheComingWeek)
    }
}
